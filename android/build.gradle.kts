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
 *
 * AppLovin MAX currently has an Android library module
 * that may declare an older compile SDK.
 *
 * Force Android library modules, including applovin_max,
 * to compile against API 36.
 */
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
