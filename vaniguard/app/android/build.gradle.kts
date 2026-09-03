allprojects {
    repositories {
        google()
        mavenCentral()
    }
    project.extra.set("flutter", mapOf(
        "compileSdkVersion" to 36,
        "targetSdkVersion" to 36,
        "minSdkVersion" to 23,
        "ndkVersion" to "27.0.12077973"
    ))
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (project.name != "app") {
        afterEvaluate {
            if (project.hasProperty("android")) {
                val android = project.extensions.findByName("android")
                if (android is com.android.build.gradle.BaseExtension) {
                    android.compileSdkVersion(36)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
