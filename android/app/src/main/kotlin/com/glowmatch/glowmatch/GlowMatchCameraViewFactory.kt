package com.glowmatch.glowmatch

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

import androidx.lifecycle.LifecycleOwner

class GlowMatchCameraViewFactory(
    private val messenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        return GlowMatchCameraView(context, viewId, messenger, lifecycleOwner, creationParams)
    }
}
