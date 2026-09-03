import datetime
from typing import Dict, Any, Optional
from server.app.database import db


class AuditService:
    """
    Immutable structured audit logging service.
    Correlates every financial mutation and security event with request_id and actor identity.
    """
    def log(
        self,
        actor_id: str,
        entity: str,
        entity_id: str,
        action: str,
        payload: Dict[str, Any],
        request_id: str
    ) -> Dict[str, Any]:
        entry = {
            "id": len(db.audit_log) + 1,
            "actor_id": actor_id,
            "entity": entity,
            "entity_id": entity_id,
            "action": action,
            "payload": payload,
            "request_id": request_id,
            "created_at": datetime.datetime.now(datetime.timezone.utc)
        }
        db.audit_log.append(entry)
        return entry

    def query(
        self,
        entity: Optional[str] = None,
        entity_id: Optional[str] = None,
        actor_id: Optional[str] = None
    ) -> list:
        records = db.audit_log
        if entity:
            records = [r for r in records if r["entity"] == entity]
        if entity_id:
            records = [r for r in records if r["entity_id"] == entity_id]
        if actor_id:
            records = [r for r in records if r["actor_id"] == actor_id]
        return records


audit_service = AuditService()
