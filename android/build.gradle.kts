import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}

subprojects {
    project.evaluationDependsOn(":app")
}

/*
 * POWER FAN NETWORK
 * Force every Android library module to compile with API 36.
 */
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 36
        }
    }

    afterEvaluate {
        extensions.findByType(LibraryExtension::class.java)?.let {
            it.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
