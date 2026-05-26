allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                // Masterclass reflection to force compileSdk / compileSdkVersion to 34
                var sdkForced = false
                for (methodName in listOf("setCompileSdk", "compileSdk", "setCompileSdkVersion", "compileSdkVersion")) {
                    for (paramType in listOf(java.lang.Integer::class.java, Int::class.javaPrimitiveType)) {
                        try {
                            val method = android.javaClass.getMethod(methodName, paramType)
                            method.invoke(android, 34)
                            sdkForced = true
                            break
                        } catch (e: Exception) {}
                    }
                    if (sdkForced) break
                }

                val getNamespace = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(android) as? String
                if (namespace.isNullOrEmpty()) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val groupName = project.group.toString()
                    val fallback = if (groupName.isNotEmpty()) groupName else "com.example.${project.name.replace("-", "_")}"
                    setNamespace.invoke(android, fallback)
                }
            } catch (e: Exception) {}
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate { configureAndroid() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
