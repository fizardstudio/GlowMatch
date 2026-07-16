package com.glowmatch.glowmatch

object GLMeshEngine {
    init {
        System.loadLibrary("gl_mesh_engine")
    }

    external fun init()
    external fun resize(width: Int, height: Int)
    external fun render(textureId: Int, landmarks: FloatArray?, landmarkCount: Int)
    external fun setLipstick(r: Float, g: Float, b: Float, opacity: Float, isGlossy: Boolean)
    external fun setBlush(r: Float, g: Float, b: Float, opacity: Float)
    external fun setFoundation(r: Float, g: Float, b: Float, opacity: Float)
    external fun destroy()
}
