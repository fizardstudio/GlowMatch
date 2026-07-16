#include "gl_renderer.h"
#include <string>

// Vertex shader for rendering the full-screen camera quad
const char* CAMERA_VS = R"glsl(#version 300 es
layout(location = 0) in vec4 aPosition;
layout(location = 1) in vec2 aTexCoord;
out vec2 vTexCoord;
void main() {
    gl_Position = aPosition;
    vTexCoord = aTexCoord;
}
)glsl";

// Fragment shader for rendering external OES texture (camera)
const char* CAMERA_FS = R"glsl(#version 300 es
#extension GL_OES_EGL_image_external_essl3 : require
precision medium float;
in vec2 vTexCoord;
out vec4 fragColor;
uniform samplerExternalOES uCameraTexture;
void main() {
    fragColor = texture(uCameraTexture, vTexCoord);
}
)glsl";

// Vertex shader for drawing makeup mesh
const char* MAKEUP_VS = R"glsl(#version 300 es
layout(location = 0) in vec2 aPosition;
void main() {
    // Translate from ML Kit / screen space coordinate to OpenGL Normalized Device Coordinates (-1 to 1)
    gl_Position = vec4(aPosition, 0.0, 1.0);
}
)glsl";

// Fragment shader for solid/matte or glossy blend rendering
const char* MAKEUP_FS = R"glsl(#version 300 es
precision medium float;
out vec4 fragColor;
uniform vec3 uColor;
uniform float uOpacity;
void main() {
    fragColor = vec4(uColor, uOpacity);
}
)glsl";

GLRenderer::GLRenderer() :
    mWidth(0), mHeight(0),
    mCameraProgram(0), mMakeupProgram(0),
    mQuadVAO(0), mQuadVBO(0),
    mMeshVAO(0), mMeshVBO(0) {
    
    // Set default cosmetics states
    mLipstickColor[0] = 1.0f; mLipstickColor[1] = 0.0f; mLipstickColor[2] = 0.0f;
    mLipstickOpacity = 0.0f;
    mLipstickGlossy = false;
    
    mBlushColor[0] = 1.0f; mBlushColor[1] = 0.5f; mBlushColor[2] = 0.5f;
    mBlushOpacity = 0.0f;
}

GLRenderer::~GLRenderer() {
    if (mCameraProgram) glDeleteProgram(mCameraProgram);
    if (mMakeupProgram) glDeleteProgram(mMakeupProgram);
    if (mQuadVAO) glDeleteVertexArrays(1, &mQuadVAO);
    if (mQuadVBO) glDeleteBuffers(1, &mQuadVBO);
    if (mMeshVAO) glDeleteVertexArrays(1, &mMeshVAO);
    if (mMeshVBO) glDeleteBuffers(1, &mMeshVBO);
}

GLuint GLRenderer::compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLint infoLen = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen > 0) {
            char* buf = new char[infoLen];
            glGetShaderInfoLog(shader, infoLen, nullptr, buf);
            LOGE("Shader compilation failed: %s", buf);
            delete[] buf;
        }
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint GLRenderer::createProgram(const char* vertexSource, const char* fragmentSource) {
    GLuint vs = compileShader(GL_VERTEX_SHADER, vertexSource);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, fragmentSource);
    if (!vs || !fs) return 0;
    
    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    
    GLint linked;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        GLint infoLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen > 0) {
            char* buf = new char[infoLen];
            glGetProgramInfoLog(program, infoLen, nullptr, buf);
            LOGE("Program linking failed: %s", buf);
            delete[] buf;
        }
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

void GLRenderer::init() {
    LOGD("Initializing GLRenderer...");
    mCameraProgram = createProgram(CAMERA_VS, CAMERA_FS);
    mMakeupProgram = createProgram(MAKEUP_VS, MAKEUP_FS);
    
    mCamPositionLoc = glGetAttribLocation(mCameraProgram, "aPosition");
    mCamTexCoordLoc = glGetAttribLocation(mCameraProgram, "aTexCoord");
    mCamTextureLoc = glGetUniformLocation(mCameraProgram, "uCameraTexture");
    
    mMakeupPositionLoc = glGetAttribLocation(mMakeupProgram, "aPosition");
    mMakeupColorLoc = glGetUniformLocation(mMakeupProgram, "uColor");
    mMakeupOpacityLoc = glGetUniformLocation(mMakeupProgram, "uOpacity");
    
    // Setup full-screen quad coordinates
    float quadVertices[] = {
        // Position      // TexCoord
        -1.0f,  1.0f,    0.0f, 1.0f,
        -1.0f, -1.0f,    0.0f, 0.0f,
         1.0f,  1.0f,    1.0f, 1.0f,
         1.0f, -1.0f,    1.0f, 0.0f,
    };
    
    glGenVertexArrays(1, &mQuadVAO);
    glGenBuffers(1, &mQuadVBO);
    
    glBindVertexArray(mQuadVAO);
    glBindBuffer(GL_ARRAY_BUFFER, mQuadVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    
    glBindVertexArray(0);
    
    // Setup makeup VBO/VAO
    glGenVertexArrays(1, &mMeshVAO);
    glGenBuffers(1, &mMeshVBO);
    glBindVertexArray(0);
}

void GLRenderer::resize(int width, int height) {
    mWidth = width;
    mHeight = height;
    glViewport(0, 0, width, height);
}

void GLRenderer::render(GLuint cameraTextureId, float* faceLandmarks, int landmarkCount) {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // 1. Draw camera background
    glUseProgram(mCameraProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(0x8D65, cameraTextureId); // GL_TEXTURE_EXTERNAL_OES is 0x8D65
    glUniform1i(mCamTextureLoc, 0);
    
    glBindVertexArray(mQuadVAO);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
    
    // 2. Draw makeup paths if landmarks are available
    if (faceLandmarks != nullptr && landmarkCount > 0) {
        glUseProgram(mMakeupProgram);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        glBindVertexArray(mMeshVAO);
        glBindBuffer(GL_ARRAY_BUFFER, mMeshVBO);
        glBufferData(GL_ARRAY_BUFFER, landmarkCount * 2 * sizeof(float), faceLandmarks, GL_DYNAMIC_DRAW);
        
        glEnableVertexAttribArray(mMakeupPositionLoc);
        glVertexAttribPointer(mMakeupPositionLoc, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
        
        // Render lipstick
        if (mLipstickOpacity > 0.0f) {
            glUniform3fv(mMakeupColorLoc, 1, mLipstickColor);
            glUniform1f(mMakeupOpacityLoc, mLipstickOpacity);
            glDrawArrays(GL_TRIANGLE_FAN, 0, landmarkCount);
        }
        
        glDisable(GL_BLEND);
        glBindVertexArray(0);
    }
}

void GLRenderer::setLipstickParams(float r, float g, float b, float opacity, bool isGlossy) {
    mLipstickColor[0] = r; mLipstickColor[1] = g; mLipstickColor[2] = b;
    mLipstickOpacity = opacity;
    mLipstickGlossy = isGlossy;
}

void GLRenderer::setBlushParams(float r, float g, float b, float opacity) {
    mBlushColor[0] = r; mBlushColor[1] = g; mBlushColor[2] = b;
    mBlushOpacity = opacity;
}

void GLRenderer::setFoundationParams(float r, float g, float b, float opacity) {
    mFoundationColor[0] = r; mFoundationColor[1] = g; mFoundationColor[2] = b;
    mFoundationOpacity = opacity;
}
