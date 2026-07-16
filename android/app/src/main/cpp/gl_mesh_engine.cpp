#include <jni.h>
#include "gl_renderer.h"

// Static instance of our renderer
static GLRenderer* gRenderer = nullptr;

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_init(JNIEnv* env, jobject thiz) {
    if (gRenderer == nullptr) {
        gRenderer = new GLRenderer();
        gRenderer->init();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_resize(JNIEnv* env, jobject thiz, jint width, jint height) {
    if (gRenderer != nullptr) {
        gRenderer->resize(width, height);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_render(JNIEnv* env, jobject thiz, jint texture_id, jfloatArray landmarks, jint landmark_count) {
    if (gRenderer != nullptr) {
        jfloat* landmark_ptr = nullptr;
        if (landmarks != nullptr) {
            landmark_ptr = env->GetFloatArrayElements(landmarks, nullptr);
        }
        
        gRenderer->render(texture_id, landmark_ptr, landmark_count);
        
        if (landmarks != nullptr && landmark_ptr != nullptr) {
            env->ReleaseFloatArrayElements(landmarks, landmark_ptr, JNI_ABORT);
        }
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_setLipstick(JNIEnv* env, jobject thiz, jfloat r, jfloat g, jfloat b, jfloat opacity, jboolean is_glossy) {
    if (gRenderer != nullptr) {
        gRenderer->setLipstickParams(r, g, b, opacity, is_glossy);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_setBlush(JNIEnv* env, jobject thiz, jfloat r, jfloat g, jfloat b, jfloat opacity) {
    if (gRenderer != nullptr) {
        gRenderer->setBlushParams(r, g, b, opacity);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_setFoundation(JNIEnv* env, jobject thiz, jfloat r, jfloat g, jfloat b, jfloat opacity) {
    if (gRenderer != nullptr) {
        gRenderer->setFoundationParams(r, g, b, opacity);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_glowmatch_glowmatch_GLMeshEngine_destroy(JNIEnv* env, jobject thiz) {
    if (gRenderer != nullptr) {
        delete gRenderer;
        gRenderer = nullptr;
    }
}
