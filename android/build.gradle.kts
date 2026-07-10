allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            val baseExt = android as? com.android.build.gradle.BaseExtension
            baseExt?.let {
                it.compileSdkVersion(36)
            }
        }
    }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    if (project.state.executed) {
        if (project.name == "isar_flutter_libs") {
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespaceMethod.invoke(android, "dev.isar.isar_flutter_libs")
                } catch (e: Exception) {
                    println("Gagal menyetel namespace langsung: \${e.message}")
                }
            }
        }
    } else {
        project.afterEvaluate {
            if (project.name == "isar_flutter_libs") {
                val android = extensions.findByName("android")
                if (android != null) {
                    try {
                        val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespaceMethod.invoke(android, "dev.isar.isar_flutter_libs")
                    } catch (e: Exception) {
                        println("Gagal menyetel namespace di afterEvaluate: \${e.message}")
                    }
                }
            }
        }
    }
}
