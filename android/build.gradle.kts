import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
    // Keep Java & Kotlin JVM targets aligned in every module. Flutter plugin
    // modules (e.g. tflite_flutter) default Kotlin to the local JDK (21) while
    // Java stays on 11, which fails the Gradle toolchain consistency check.
    // configureEach runs as a deferred rule, so registration order does not
    // matter and no afterEvaluate is needed.
    pluginManager.withPlugin("org.jetbrains.kotlin.android") {
        tasks.withType<KotlinJvmCompile>().configureEach {
            compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
        }
    }
}
// AGP finalizes each project's variant config during its own evaluation;
// JavaCompile targets are derived from compileOptions then. Stamp the final
// value once every project is evaluated so the Java side cannot stay behind.
val _rootProject = project
gradle.projectsEvaluated {
    _rootProject.subprojects {
        tasks.withType<JavaCompile>().configureEach {
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
