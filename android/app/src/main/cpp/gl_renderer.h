#ifndef GL_RENDERER_H
#define GL_RENDERER_H

#include <GLES3/gl3.h>
#include <EGL/egl.h>
#include <android/log.h>

#define LOG_TAG "GLMeshEngineRenderer"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

class GLRenderer {
public:
    GLRenderer();
    ~GLRenderer();

    void init();
    void resize(int width, int height);
    void render(GLuint cameraTextureId, float* faceLandmarks, int landmarkCount);
    
    // Makeup options
    void setLipstickParams(float r, float g, float b, float opacity, bool isGlossy);
    void setBlushParams(float r, float g, float b, float opacity);
    void setFoundationParams(float r, float g, float b, float opacity);

private:
    GLuint compileShader(GLenum type, const char* source);
    GLuint createProgram(const char* vertexSource, const char* fragmentSource);

    // Viewport size
    int mWidth;
    int mHeight;

    // Shader programs
    GLuint mCameraProgram;
    GLuint mMakeupProgram;

    // Shader locations for camera preview
    GLint mCamPositionLoc;
    GLint mCamTexCoordLoc;
    GLint mCamTextureLoc;

    // Shader locations for makeup
    GLint mMakeupPositionLoc;
    GLint mMakeupColorLoc;
    GLint mMakeupOpacityLoc;

    // Makeup color states
    float mLipstickColor[3];
    float mLipstickOpacity;
    bool mLipstickGlossy;

    float mBlushColor[3];
    float mBlushOpacity;

    float mFoundationColor[3];
    float mFoundationOpacity;

    // VBO/VAO helpers
    GLuint mQuadVAO, mQuadVBO;
    GLuint mMeshVAO, mMeshVBO;
};

#endif // GL_RENDERER_H
