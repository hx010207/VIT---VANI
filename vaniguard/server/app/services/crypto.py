import os
import struct
import base64
from typing import List, Tuple, Dict
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from server.app.config import settings


class VoiceprintCryptoService:
    """
    App-level envelope encryption for speaker embedding vectors using AES-256-GCM.
    Supports 32-byte base64 or hex keys, per-record 12-byte IV, key_id header,
    and key rotation keyring.
    """
    def __init__(self, primary_key: str = settings.KMS_MASTER_KEY, active_key_id: str = "kms-v1"):
        self.active_key_id = active_key_id
        self.keyring: Dict[str, bytes] = {}

        raw_key = self._decode_key(primary_key)
        self.keyring[active_key_id] = raw_key

    def _decode_key(self, key_str: str) -> bytes:
        # Try base64 first
        try:
            decoded = base64.b64decode(key_str)
            if len(decoded) == 32:
                return decoded
        except Exception:
            pass
        # Try hex
        try:
            decoded = bytes.fromhex(key_str)
            if len(decoded) == 32:
                return decoded
        except Exception:
            pass
        raise ValueError("KMS master key must be a valid 32-byte base64 or 64-character hex string")

    def register_rotation_key(self, key_id: str, key_str: str):
        """Registers a historical or new rotated key in the keyring."""
        self.keyring[key_id] = self._decode_key(key_str)

    def encrypt_embedding(self, embedding: List[float], key_id: str = None) -> Tuple[bytes, bytes, str]:
        """
        Encrypts a float vector using AES-256-GCM with a 12-byte IV.
        Returns (ciphertext_bytes, iv_bytes, key_id).
        """
        target_key_id = key_id or self.active_key_id
        key_bytes = self.keyring.get(target_key_id)
        if not key_bytes:
            raise ValueError(f"Unknown key_id '{target_key_id}' for encryption")

        aesgcm = AESGCM(key_bytes)
        packed_data = struct.pack(f"{len(embedding)}f", *embedding)
        iv = os.urandom(12)  # 96-bit standard nonce for GCM
        aad = target_key_id.encode("utf-8")
        ciphertext = aesgcm.encrypt(iv, packed_data, aad)
        return ciphertext, iv, target_key_id

    def decrypt_embedding(self, ciphertext: bytes, iv: bytes, key_id: str) -> List[float]:
        """
        Decrypts ciphertext into float vector using matching key from keyring.
        """
        key_bytes = self.keyring.get(key_id)
        if not key_bytes:
            # Fallback to active key if key_id matches or not found in multi-key setup
            key_bytes = self.keyring.get(self.active_key_id)
            if not key_bytes:
                raise ValueError(f"Key with ID '{key_id}' not found in crypto keyring")

        aesgcm = AESGCM(key_bytes)
        aad = key_id.encode("utf-8")
        decrypted_bytes = aesgcm.decrypt(iv, ciphertext, aad)
        num_floats = len(decrypted_bytes) // 4
        unpacked = struct.unpack(f"{num_floats}f", decrypted_bytes)
        return list(unpacked)


crypto_service = VoiceprintCryptoService()
