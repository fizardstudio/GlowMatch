package com.glowmatch.glowmatch

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

import android.util.Log

class GlowMatchCameraView(
    private val context: Context,
    private val id: Int,
    private val messenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner,
    creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler {

    private val container: FrameLayout = FrameLayout(context)
    private val previewView: PreviewView = PreviewView(context)
    private val overlayView: MakeupOverlayView = MakeupOverlayView(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.glowmatch.glowmatch/camera_view_$id")
    
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var lensFacing: Int = CameraSelector.LENS_FACING_FRONT
    private val detector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
            .build()
    )

    init {
        // Force TextureView implementation mode so it integrates with Flutter's compositing
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE

        // Setup layout
        previewView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        overlayView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        
        container.addView(previewView)
        container.addView(overlayView)

        // Parse initial parameters
        creationParams?.let { updateOverlayParams(it) }

        methodChannel.setMethodCallHandler(this)
        
        // Start Camera
        startCamera()
    }

    override fun getView(): View = container

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        cameraExecutor.shutdown()
        detector.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateParams" -> {
                val params = call.arguments as? Map<String, Any>
                if (params != null) {
                    updateOverlayParams(params)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Params cannot be null", null)
                }
            }
            "switchCamera" -> {
                lensFacing = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                    CameraSelector.LENS_FACING_BACK
                } else {
                    CameraSelector.LENS_FACING_FRONT
                }
                overlayView.isFrontCamera = (lensFacing == CameraSelector.LENS_FACING_FRONT)
                mainHandler.post {
                    startCamera()
                }
                result.success(lensFacing == CameraSelector.LENS_FACING_FRONT)
            }
            else -> result.notImplemented()
        }
    }

    private fun updateOverlayParams(params: Map<String, Any>) {
        (params["lipstickColor"] as? Number)?.let { overlayView.lipstickColor = it.toInt() }
        (params["lipstickOpacity"] as? Number)?.let { overlayView.lipstickOpacity = it.toFloat() }
        (params["lipstickFinishing"] as? String)?.let { overlayView.lipstickFinishing = it }
        
        (params["blushColor"] as? Number)?.let { overlayView.blushColor = it.toInt() }
        (params["blushOpacity"] as? Number)?.let { overlayView.blushOpacity = it.toFloat() }
        
        (params["foundationColor"] as? Number)?.let { overlayView.foundationColor = it.toInt() }
        (params["foundationOpacity"] as? Number)?.let { overlayView.foundationOpacity = it.toFloat() }
        (params["foundationFinishing"] as? String)?.let { overlayView.foundationFinishing = it }
        
        (params["eyeshadowColor"] as? Number)?.let { overlayView.eyeshadowColor = it.toInt() }
        (params["eyeshadowOpacity"] as? Number)?.let { overlayView.eyeshadowOpacity = it.toFloat() }
        (params["eyeshadowShape"] as? String)?.let { overlayView.eyeshadowShape = it }
        
        (params["hasEyeliner"] as? Boolean)?.let { overlayView.hasEyeliner = it }
        (params["eyelinerThickness"] as? Number)?.let { overlayView.eyelinerThickness = it.toFloat() }
        
        (params["noseHighlightOpacity"] as? Number)?.let { overlayView.noseHighlightOpacity = it.toFloat() }
        (params["noseShadingOpacity"] as? Number)?.let { overlayView.noseShadingOpacity = it.toFloat() }
        (params["showContourGuide"] as? Boolean)?.let { overlayView.showContourGuide = it }
        (params["isCapturing"] as? Boolean)?.let { overlayView.isCapturing = it }
        (params["sliderX"] as? Number)?.let { overlayView.sliderX = it.toFloat() }
        
        overlayView.postInvalidate()
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider: ProcessCameraProvider = cameraProviderFuture.get()

            // Preview with explicit 16:9 aspect ratio
            val preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                .build()
                .also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

            // Image Analysis with 16:9 aspect ratio matching preview exactly to avoid layout offset and scaling issues
            val imageAnalyzer = ImageAnalysis.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor, FaceAnalyzer())
                }

            // Select Front or Back Camera
            val cameraSelector = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                CameraSelector.DEFAULT_FRONT_CAMERA
            } else {
                CameraSelector.DEFAULT_BACK_CAMERA
            }

            try {
                Log.d("GlowMatchCameraView", "startCamera: Binding camera use cases to lifecycleOwner")
                // Unbind use cases before rebinding
                cameraProvider.unbindAll()

                // Bind use cases to camera
                cameraProvider.bindToLifecycle(
                    lifecycleOwner, cameraSelector, preview, imageAnalyzer
                )
                Log.d("GlowMatchCameraView", "startCamera: Camera provider bound successfully")
            } catch (exc: Exception) {
                Log.e("GlowMatchCameraView", "startCamera error", exc)
                exc.printStackTrace()
            }

        }, ContextCompat.getMainExecutor(context))
    }

    private inner class FaceAnalyzer : ImageAnalysis.Analyzer {
        private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

        @androidx.annotation.OptIn(ExperimentalGetImage::class)
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage != null) {
                val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                detector.process(image)
                    .addOnSuccessListener { faces ->
                        if (faces.isNotEmpty()) {
                            val face = faces[0]
                            Log.d("GlowMatchCameraView", "FaceAnalyzer: Face detected! Update overlay.")
                            overlayView.updateFace(face, imageProxy.width, imageProxy.height, imageProxy.imageInfo.rotationDegrees)

                            val shape = overlayView.classifyFaceShape(face)
                            val smileProb = (face.smilingProbability ?: 0f).toDouble()
                            mainHandler.post {
                                methodChannel.invokeMethod("onFaceDetected", mapOf(
                                    "faceShape" to shape,
                                    "smilingProbability" to smileProb
                                ))
                            }
                        } else {
                            overlayView.clearFace()
                            mainHandler.post {
                                methodChannel.invokeMethod("onFaceLost", null)
                            }
                        }
                    }
                    .addOnFailureListener { e ->
                        Log.e("GlowMatchCameraView", "FaceAnalyzer: ML Kit face detection failure", e)
                        e.printStackTrace()
                    }
                    .addOnCompleteListener {
                        imageProxy.close()
                    }
            } else {
                imageProxy.close()
            }
        }
    }
}

class MakeupOverlayView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    var face: Face? = null
    var isFrontCamera: Boolean = true
    var imageWidth: Int = 0
    var imageHeight: Int = 0

    // Paint options
    var lipstickColor: Int = 0xFFD81B60.toInt()
    var lipstickOpacity: Float = 0.40f
    var lipstickFinishing: String = "matte"

    var blushColor: Int = 0xFFFF8A80.toInt()
    var blushOpacity: Float = 0.25f

    var foundationColor: Int = Color.TRANSPARENT
    var foundationOpacity: Float = 0f
    var foundationFinishing: String = "dewy"

    var eyeshadowColor: Int = 0xFFFFCC80.toInt()
    var eyeshadowOpacity: Float = 0f
    var eyeshadowShape: String = "gradient"

    var hasEyeliner: Boolean = false
    var eyelinerThickness: Float = 0.5f

    var noseHighlightOpacity: Float = 0f
    var noseShadingOpacity: Float = 0f
    var showContourGuide: Boolean = false
    var isCapturing: Boolean = false
    var sliderX: Float = 0f
    private var rotationDegrees = 270

    private val smoothedContours = HashMap<Int, List<PointF>>()
    private val smoothingFactor = 0.78f // 78% new frame, 22% history. Higher = faster, lower = smoother.
    private var maxLipThicknessRatio = 0.03f

    private fun getSmoothedContour(face: Face, contourType: Int): List<PointF>? {
        val rawPoints = face.getContour(contourType)?.points ?: return null
        if (rawPoints.isEmpty()) return null

        val history = smoothedContours[contourType]
        if (history == null || history.size != rawPoints.size) {
            val initialized = rawPoints.map { PointF(it.x, it.y) }
            smoothedContours[contourType] = initialized
            return initialized
        }

        val smoothed = ArrayList<PointF>(rawPoints.size)
        for (i in rawPoints.indices) {
            val raw = rawPoints[i]
            val prev = history[i]
            val sx = raw.x * smoothingFactor + prev.x * (1f - smoothingFactor)
            val sy = raw.y * smoothingFactor + prev.y * (1f - smoothingFactor)
            val smoothedPt = PointF(sx, sy)
            smoothed.add(smoothedPt)
            prev.set(sx, sy)
        }
        return smoothed
    }

    private val pathPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }

    fun updateFace(face: Face, width: Int, height: Int, rotationDegrees: Int) {
        this.face = face
        this.imageWidth = width
        this.imageHeight = height
        this.rotationDegrees = rotationDegrees
        postInvalidate()
    }

    fun clearFace() {
        this.face = null
        smoothedContours.clear()
        maxLipThicknessRatio = 0.03f
        postInvalidate()
    }

    private fun getEyeCenter(points: List<PointF>): PointF {
        var sumX = 0f
        var sumY = 0f
        for (p in points) {
            sumX += p.x
            sumY += p.y
        }
        return PointF(sumX / points.size, sumY / points.size)
    }

    private fun getPathCentroid(top: List<PointF>, bottom: List<PointF>): PointF {
        var sumX = 0f
        var sumY = 0f
        var count = 0
        for (pt in top) {
            sumX += pt.x
            sumY += pt.y
            count++
        }
        for (pt in bottom) {
            sumX += pt.x
            sumY += pt.y
            count++
        }
        return if (count > 0) PointF(sumX / count, sumY / count) else PointF(0f, 0f)
    }

    private fun getFaceUnitVectors(face: Face, leftCenter: PointF, rightCenter: PointF): Map<String, PointF> {
        val dxVal = rightCenter.x - leftCenter.x
        val dyVal = rightCenter.y - leftCenter.y
        val eyeDistance = Math.sqrt((dxVal * dxVal + dyVal * dyVal).toDouble()).toFloat()

        val unitX = if (eyeDistance > 0f) PointF(dxVal / eyeDistance, dyVal / eyeDistance) else PointF(1f, 0f)
        var unitY = PointF(-unitX.y, unitX.x)

        var referencePoint: PointF? = null
        val upperLip = face.getContour(FaceContour.UPPER_LIP_TOP)?.points
        if (upperLip != null && upperLip.isNotEmpty()) {
            referencePoint = upperLip[upperLip.size / 2]
        }

        val midEyeX = (leftCenter.x + rightCenter.x) / 2f
        val midEyeY = (leftCenter.y + rightCenter.y) / 2f

        if (referencePoint != null) {
            val refX = referencePoint.x - midEyeX
            val refY = referencePoint.y - midEyeY
            val dot = unitY.x * refX + unitY.y * refY
            if (dot < 0f) {
                unitY = PointF(-unitY.x, -unitY.y)
            }
        } else {
            val rollDeg = face.headEulerAngleZ ?: 0f
            val rollRad = (rollDeg * Math.PI / 180.0).toFloat()
            val expY_x = -Math.sin(rollRad.toDouble()).toFloat()
            val expY_y = Math.cos(rollRad.toDouble()).toFloat()
            val dot = unitY.x * expY_x + unitY.y * expY_y
            if (dot < 0f) {
                unitY = PointF(-unitY.x, -unitY.y)
            }
        }

        return mapOf(
            "unitX" to unitX,
            "unitY" to unitY,
            "distance" to PointF(eyeDistance, eyeDistance)
        )
    }

    private fun getHairlinePoints(face: Face): List<PointF> {
        val leftEye = getSmoothedContour(face, FaceContour.LEFT_EYE) ?: emptyList()
        val rightEye = getSmoothedContour(face, FaceContour.RIGHT_EYE) ?: emptyList()

        if (leftEye.isEmpty() || rightEye.isEmpty()) {
            val bbox = face.boundingBox
            val w = bbox.width().toFloat()
            return listOf(
                PointF(bbox.left + w * 0.15f, bbox.top.toFloat()),
                PointF(bbox.centerX().toFloat(), bbox.top - w * 0.20f),
                PointF(bbox.right - w * 0.15f, bbox.top.toFloat())
            )
        }

        val leftCenter = getEyeCenter(leftEye)
        val rightCenter = getEyeCenter(rightEye)

        val vectors = getFaceUnitVectors(face, leftCenter, rightCenter)
        val unitX = vectors["unitX"]!!
        val unitY = vectors["unitY"]!!
        val eyeDistance = vectors["distance"]!!.x

        val midX = (leftCenter.x + rightCenter.x) / 2.0f
        val midY = (leftCenter.y + rightCenter.y) / 2.0f

        val fhLeftX = leftCenter.x - unitX.x * (eyeDistance * 0.15f) - unitY.x * (eyeDistance * 0.85f)
        val fhLeftY = leftCenter.y - unitX.y * (eyeDistance * 0.15f) - unitY.y * (eyeDistance * 0.85f)

        val fhCenterX = midX - unitY.x * (eyeDistance * 0.95f)
        val fhCenterY = midY - unitY.y * (eyeDistance * 0.95f)

        val fhRightX = rightCenter.x + unitX.x * (eyeDistance * 0.15f) - unitY.x * (eyeDistance * 0.85f)
        val fhRightY = rightCenter.y + unitX.y * (eyeDistance * 0.15f) - unitY.y * (eyeDistance * 0.85f)

        return listOf(
            PointF(fhLeftX, fhLeftY),
            PointF(fhCenterX, fhCenterY),
            PointF(fhRightX, fhRightY)
        )
    }

    private fun getCheekboneCoordinates(face: Face): Map<String, PointF> {
        val leftEye = getSmoothedContour(face, FaceContour.LEFT_EYE) ?: emptyList()
        val rightEye = getSmoothedContour(face, FaceContour.RIGHT_EYE) ?: emptyList()

        if (leftEye.isEmpty() || rightEye.isEmpty()) {
            val bbox = face.boundingBox
            val w = bbox.width().toFloat()
            val leftCheek = PointF(bbox.left + w * 0.25f, bbox.centerY().toFloat())
            val rightCheek = PointF(bbox.right - w * 0.25f, bbox.centerY().toFloat())
            return mapOf("left" to leftCheek, "right" to rightCheek)
        }

        val leftCenter = getEyeCenter(leftEye)
        val rightCenter = getEyeCenter(rightEye)

        val vectors = getFaceUnitVectors(face, leftCenter, rightCenter)
        val unitX = vectors["unitX"]!!
        val unitY = vectors["unitY"]!!
        val eyeDistance = vectors["distance"]!!.x

        val boxW = face.boundingBox.width().toFloat()
        val boxH = face.boundingBox.height().toFloat()
        val ratio = boxH / boxW

        val downFactor: Float
        val outFactor: Float

        if (ratio < 1.13f) {
            downFactor = 0.43f
            outFactor = 0.25f
        } else if (ratio > 1.25f) {
            downFactor = 0.47f
            outFactor = 0.17f
        } else {
            downFactor = 0.45f
            outFactor = 0.21f
        }

        val leftCheekX = leftCenter.x + unitY.x * (eyeDistance * downFactor) - unitX.x * (eyeDistance * outFactor)
        val leftCheekY = leftCenter.y + unitY.y * (eyeDistance * downFactor) - unitX.y * (eyeDistance * outFactor)

        val rightCheekX = rightCenter.x + unitY.x * (eyeDistance * downFactor) + unitX.x * (eyeDistance * outFactor)
        val rightCheekY = rightCenter.y + unitY.y * (eyeDistance * downFactor) + unitX.y * (eyeDistance * outFactor)

        return mapOf(
            "left" to PointF(leftCheekX, leftCheekY),
            "right" to PointF(rightCheekX, rightCheekY)
        )
    }

    fun classifyFaceShape(face: Face): String {
        val boxW = face.boundingBox.width().toFloat()
        val boxH = face.boundingBox.height().toFloat()
        if (boxW == 0f) return "oval"
        val ratio = boxH / boxW

        if (ratio > 1.25f) {
            return "long"
        } else if (ratio < 1.13f) {
            val faceContour = face.getContour(FaceContour.FACE)?.points
            if (faceContour != null && faceContour.size >= 33) {
                val pLeftForehead = faceContour[4]
                val pRightForehead = faceContour[32]
                val pLeftJaw = faceContour[12]
                val pRightJaw = faceContour[24]

                val foreheadWidth = Math.abs(pRightForehead.x - pLeftForehead.x)
                val jawWidth = Math.abs(pRightJaw.x - pLeftJaw.x)

                if (foreheadWidth > 0f && jawWidth > 0f) {
                    val jawRatio = jawWidth / foreheadWidth
                    if (jawRatio > 0.90f) {
                        return "square"
                    }
                }
            }
            return "round"
        } else {
            val faceContour = face.getContour(FaceContour.FACE)?.points
            if (faceContour != null && faceContour.size >= 33) {
                val pLeftForehead = faceContour[4]
                val pRightForehead = faceContour[32]
                val pLeftJaw = faceContour[12]
                val pRightJaw = faceContour[24]

                val foreheadWidth = Math.abs(pRightForehead.x - pLeftForehead.x)
                val jawWidth = Math.abs(pRightJaw.x - pLeftJaw.x)

                if (foreheadWidth > 0f && jawWidth > 0f) {
                    val jawRatio = jawWidth / foreheadWidth
                    if (jawRatio < 0.72f) {
                        return "heart"
                    }
                }
            }
            return "oval"
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val currentFace = face ?: return
        if (imageWidth == 0 || imageHeight == 0) return

        Log.d("GlowMatchCameraView", "onDraw: imageWidth=$imageWidth, imageHeight=$imageHeight, viewWidth=$width, viewHeight=$height, rotationDegrees=$rotationDegrees, faceBounds=${currentFace.boundingBox}")

        // ML Kit rotation is 270 deg for front camera, which means coordinate space is rotated:
        // rotatedWidth = imageHeight, rotatedHeight = imageWidth.
        val rotatedWidth = imageHeight
        val rotatedHeight = imageWidth

        // Calculate uniform scaling and centering offset matching PreviewView's FILL_CENTER scale type
        val scale = maxOf(width.toFloat() / rotatedWidth.toFloat(), height.toFloat() / rotatedHeight.toFloat())
        val dx = (width.toFloat() - rotatedWidth.toFloat() * scale) / 2f
        val dy = (height.toFloat() - rotatedHeight.toFloat() * scale) / 2f

        fun mapPoint(point: PointF): PointF {
            // ML Kit coordinates are already rotated to portrait space by InputImage(rotationDegrees).
            // Since it's the front camera, we only need to mirror the X axis horizontally.
            val rx = if (isFrontCamera) (imageHeight.toFloat() - point.x) else point.x
            val ry = point.y

            val mappedX = rx * scale + dx
            val mappedY = ry * scale + dy
            return PointF(mappedX, mappedY)
        }

        var leftScreenEye: PointF? = null
        var rightScreenEye: PointF? = null
        var screenUnitX = PointF(1f, 0f)
        var screenUnitY = PointF(0f, 1f)
        var eyeDistance = 0f

        val leftEyeContour = getSmoothedContour(currentFace, FaceContour.LEFT_EYE)
        val rightEyeContour = getSmoothedContour(currentFace, FaceContour.RIGHT_EYE)
        if (leftEyeContour != null && leftEyeContour.isNotEmpty() && rightEyeContour != null && rightEyeContour.isNotEmpty()) {
            val leftCenter = getEyeCenter(leftEyeContour)
            val rightCenter = getEyeCenter(rightEyeContour)

            val lEye = mapPoint(leftCenter)
            val rEye = mapPoint(rightCenter)
            leftScreenEye = lEye
            rightScreenEye = rEye

            val dxVal = rEye.x - lEye.x
            val dyVal = rEye.y - lEye.y
            eyeDistance = Math.sqrt((dxVal * dxVal + dyVal * dyVal).toDouble()).toFloat()

            if (eyeDistance > 0f) {
                screenUnitX = PointF(dxVal / eyeDistance, dyVal / eyeDistance)
            }
            screenUnitY = PointF(-screenUnitX.y, screenUnitX.x)

            // Dot product check in screen space to guarantee screenUnitY points downwards on the screen (positive screen Y direction)
            val midScreenEye = PointF((lEye.x + rEye.x) / 2f, (lEye.y + rEye.y) / 2f)
            val upperLipPoints = getSmoothedContour(currentFace, FaceContour.UPPER_LIP_TOP)
            if (upperLipPoints != null && upperLipPoints.isNotEmpty()) {
                val refScreen = mapPoint(upperLipPoints[upperLipPoints.size / 2])
                val refX = refScreen.x - midScreenEye.x
                val refY = refScreen.y - midScreenEye.y
                val dot = screenUnitY.x * refX + screenUnitY.y * refY
                if (dot < 0f) {
                    screenUnitY = PointF(-screenUnitY.x, -screenUnitY.y)
                }
            } else {
                if (screenUnitY.y < 0f) {
                    screenUnitY = PointF(-screenUnitY.x, -screenUnitY.y)
                }
            }
        }

        // Draw Split screen clip
        canvas.save()
        if (sliderX > 0f) {
            canvas.clipRect(sliderX, 0f, width.toFloat(), height.toFloat())
        }

        // 1. Foundation (Base) - Combines face path with difference cutouts of eyes, eyebrows, and mouth for 100% realistic premium look
        if (foundationColor != Color.TRANSPARENT && foundationOpacity > 0f) {
            val faceContourPoints = getSmoothedContour(currentFace, FaceContour.FACE)
            if (faceContourPoints != null && faceContourPoints.isNotEmpty()) {
                val facePath = Path()
                val faceOffsets = ArrayList<PointF>()
                for (p in faceContourPoints) {
                    faceOffsets.add(mapPoint(p))
                }
                
                // Perluas dahi ke arah hairline
                val hairlinePts = getHairlinePoints(currentFace)
                faceOffsets.add(mapPoint(hairlinePts[0]))
                faceOffsets.add(mapPoint(hairlinePts[1]))
                faceOffsets.add(mapPoint(hairlinePts[2]))
                
                facePath.moveTo(faceOffsets[0].x, faceOffsets[0].y)
                for (i in 1 until faceOffsets.size) {
                    facePath.lineTo(faceOffsets[i].x, faceOffsets[i].y)
                }
                facePath.close()

                // Buat lubang cutout agar tidak menutupi mata, alis, dan mulut
                val holesPath = Path()

                // Mata Kiri
                val leftEye = getSmoothedContour(currentFace, FaceContour.LEFT_EYE)
                if (leftEye != null && leftEye.isNotEmpty()) {
                    val leftEyePath = Path()
                    val p0 = mapPoint(leftEye[0])
                    leftEyePath.moveTo(p0.x, p0.y)
                    for (i in 1 until leftEye.size) {
                        val pt = mapPoint(leftEye[i])
                        leftEyePath.lineTo(pt.x, pt.y)
                    }
                    leftEyePath.close()
                    holesPath.addPath(leftEyePath)
                }

                // Mata Kanan
                val rightEye = getSmoothedContour(currentFace, FaceContour.RIGHT_EYE)
                if (rightEye != null && rightEye.isNotEmpty()) {
                    val rightEyePath = Path()
                    val p0 = mapPoint(rightEye[0])
                    rightEyePath.moveTo(p0.x, p0.y)
                    for (i in 1 until rightEye.size) {
                        val pt = mapPoint(rightEye[i])
                        rightEyePath.lineTo(pt.x, pt.y)
                    }
                    rightEyePath.close()
                    holesPath.addPath(rightEyePath)
                }

                // Bibir (Mulut luar)
                val upperLipTop = getSmoothedContour(currentFace, FaceContour.UPPER_LIP_TOP)
                val lowerLipBottom = getSmoothedContour(currentFace, FaceContour.LOWER_LIP_BOTTOM)
                if (upperLipTop != null && upperLipTop.isNotEmpty() && lowerLipBottom != null && lowerLipBottom.isNotEmpty()) {
                    val lipsPath = Path()
                    val lipsOffsets = ArrayList<PointF>()
                    for (p in upperLipTop) {
                        lipsOffsets.add(mapPoint(p))
                    }
                    for (i in lowerLipBottom.size - 1 downTo 0) {
                        lipsOffsets.add(mapPoint(lowerLipBottom[i]))
                    }
                    lipsPath.moveTo(lipsOffsets[0].x, lipsOffsets[0].y)
                    for (i in 1 until lipsOffsets.size) {
                        lipsPath.lineTo(lipsOffsets[i].x, lipsOffsets[i].y)
                    }
                    lipsPath.close()
                    holesPath.addPath(lipsPath)
                }

                // Alis Kiri
                val leftEyebrowTop = getSmoothedContour(currentFace, FaceContour.LEFT_EYEBROW_TOP)
                val leftEyebrowBottom = getSmoothedContour(currentFace, FaceContour.LEFT_EYEBROW_BOTTOM)
                if (leftEyebrowTop != null && leftEyebrowTop.isNotEmpty()) {
                    val eyebrowPath = Path()
                    val eyebrowOffsets = ArrayList<PointF>()
                    for (p in leftEyebrowTop) {
                        eyebrowOffsets.add(mapPoint(p))
                    }
                    if (leftEyebrowBottom != null) {
                        for (i in leftEyebrowBottom.size - 1 downTo 0) {
                            eyebrowOffsets.add(mapPoint(leftEyebrowBottom[i]))
                        }
                    }
                    eyebrowPath.moveTo(eyebrowOffsets[0].x, eyebrowOffsets[0].y)
                    for (i in 1 until eyebrowOffsets.size) {
                        eyebrowPath.lineTo(eyebrowOffsets[i].x, eyebrowOffsets[i].y)
                    }
                    eyebrowPath.close()
                    holesPath.addPath(eyebrowPath)
                }
 
                // Alis Kanan
                val rightEyebrowTop = getSmoothedContour(currentFace, FaceContour.RIGHT_EYEBROW_TOP)
                val rightEyebrowBottom = getSmoothedContour(currentFace, FaceContour.RIGHT_EYEBROW_BOTTOM)
                if (rightEyebrowTop != null && rightEyebrowTop.isNotEmpty()) {
                    val eyebrowPath = Path()
                    val eyebrowOffsets = ArrayList<PointF>()
                    for (p in rightEyebrowTop) {
                        eyebrowOffsets.add(mapPoint(p))
                    }
                    if (rightEyebrowBottom != null) {
                        for (i in rightEyebrowBottom.size - 1 downTo 0) {
                            eyebrowOffsets.add(mapPoint(rightEyebrowBottom[i]))
                        }
                    }
                    eyebrowPath.moveTo(eyebrowOffsets[0].x, eyebrowOffsets[0].y)
                    for (i in 1 until eyebrowOffsets.size) {
                        eyebrowPath.lineTo(eyebrowOffsets[i].x, eyebrowOffsets[i].y)
                    }
                    eyebrowPath.close()
                    holesPath.addPath(eyebrowPath)
                }

                val finalFoundationPath = Path()
                finalFoundationPath.op(facePath, holesPath, Path.Op.DIFFERENCE)

                pathPaint.color = foundationColor
                pathPaint.alpha = (foundationOpacity * 120).toInt() // natural base overlay blending
                pathPaint.maskFilter = BlurMaskFilter(15f, BlurMaskFilter.Blur.NORMAL)

                canvas.drawPath(finalFoundationPath, pathPaint)
                pathPaint.maskFilter = null

                // Glass Skin Glow Overlay for Satin / Dewy finishing
                if (foundationFinishing != "matte") {
                    val isDewy = foundationFinishing == "dewy"
                    val faceWidth = currentFace.boundingBox.width().toFloat() * scale
                    
                    val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.FILL
                        xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.SCREEN)
                    }

                    // Cheeks Glow
                    if (blushColor != Color.TRANSPARENT && blushOpacity > 0f) {
                        val cheeks = getCheekboneCoordinates(currentFace)
                        val leftCheek = mapPoint(cheeks["left"] ?: PointF(0f, 0f))
                        val rightCheek = mapPoint(cheeks["right"] ?: PointF(0f, 0f))
                        val cheekRadius = faceWidth * (if (isDewy) 0.18f else 0.22f)
                        val baseCheekOpacity = if (isDewy) 0.22f else 0.12f
                        val currentCheekOpacity = (baseCheekOpacity * (blushOpacity * 2.0f)).coerceIn(0.0f, 1.0f)

                        fun drawGlowCircle(center: PointF, radius: Float, opacity: Float) {
                            if (radius <= 0f || opacity <= 0f) return
                            val glowShader = android.graphics.RadialGradient(
                                center.x,
                                center.y,
                                radius,
                                intArrayOf(
                                    Color.argb((opacity * 255).toInt(), 255, 255, 255),
                                    Color.TRANSPARENT
                                ),
                                floatArrayOf(0.0f, 1.0f),
                                android.graphics.Shader.TileMode.CLAMP
                            )
                            glowPaint.shader = glowShader
                            canvas.drawCircle(center.x, center.y, radius, glowPaint)
                        }

                        drawGlowCircle(leftCheek, cheekRadius, currentCheekOpacity)
                        drawGlowCircle(rightCheek, cheekRadius, currentCheekOpacity)
                    }

                    // T-Zone Glow (Dahi & Ujung Hidung)
                    if (noseHighlightOpacity > 0f) {
                        // Forehead
                        val foreheadPoints = getHairlinePoints(currentFace)
                        if (foreheadPoints.size > 1) {
                            val forehead = mapPoint(foreheadPoints[1])
                            val foreheadRadius = faceWidth * (if (isDewy) 0.20f else 0.24f)
                            val baseForeheadOpacity = if (isDewy) 0.15f else 0.08f
                            val currentForeheadOpacity = (baseForeheadOpacity * noseHighlightOpacity).coerceIn(0.0f, 1.0f)
                            
                            val glowShader = android.graphics.RadialGradient(
                                forehead.x,
                                forehead.y,
                                foreheadRadius,
                                intArrayOf(
                                    Color.argb((currentForeheadOpacity * 255).toInt(), 255, 255, 255),
                                    Color.TRANSPARENT
                                ),
                                floatArrayOf(0.0f, 1.0f),
                                android.graphics.Shader.TileMode.CLAMP
                            )
                            glowPaint.shader = glowShader
                            canvas.drawCircle(forehead.x, forehead.y, foreheadRadius, glowPaint)
                        }

                        // Nose Tip
                        val noseBridgePoints = getSmoothedContour(currentFace, FaceContour.NOSE_BRIDGE) ?: emptyList()
                        if (noseBridgePoints.isNotEmpty()) {
                            val noseTip = mapPoint(noseBridgePoints.last())
                            val noseRadius = faceWidth * (if (isDewy) 0.04f else 0.06f)
                            val baseNoseOpacity = if (isDewy) 0.25f else 0.15f
                            val currentNoseOpacity = (baseNoseOpacity * noseHighlightOpacity).coerceIn(0.0f, 1.0f)

                            val glowShader = android.graphics.RadialGradient(
                                noseTip.x,
                                noseTip.y,
                                noseRadius,
                                intArrayOf(
                                    Color.argb((currentNoseOpacity * 255).toInt(), 255, 255, 255),
                                    Color.TRANSPARENT
                                ),
                                floatArrayOf(0.0f, 1.0f),
                                android.graphics.Shader.TileMode.CLAMP
                            )
                            glowPaint.shader = glowShader
                            canvas.drawCircle(noseTip.x, noseTip.y, noseRadius, glowPaint)
                        }
                    }
                }
            }
        }

        // 2. Eyeshadow & Eyeliner
        if ((eyeshadowColor != Color.TRANSPARENT && eyeshadowOpacity > 0f) || hasEyeliner) {
            val leftEye = getSmoothedContour(currentFace, FaceContour.LEFT_EYE)
            val rightEye = getSmoothedContour(currentFace, FaceContour.RIGHT_EYE)

            if (leftEye != null && leftEye.isNotEmpty() && rightEye != null && rightEye.isNotEmpty()) {
                // We reuse screenUnitX, screenUnitY, and eyeDistance calculated at the top of onDraw

                fun drawEyeMakeup(eyePoints: List<PointF>?, isEyeOnLeftOfScreen: Boolean) {
                    if (eyePoints == null || eyePoints.size < 9) return

                    val mappedEye = eyePoints.map { mapPoint(it) }
                    val upperLid = mappedEye.subList(0, 9)

                    // 1. EYESHADOW RENDER
                    if (eyeshadowColor != Color.TRANSPARENT && eyeshadowOpacity > 0f) {
                        val eyeshadowPath = Path()
                        val shiftedPoints = ArrayList<PointF>()

                        for (i in 0 until upperLid.size) {
                            val bellFactor = Math.sin(i / 8.0 * Math.PI).toFloat()
                            val shapeFactor = when (eyeshadowShape) {
                                "cat_eye" -> {
                                    // Cat eye: higher towards the outer edge (index 8)
                                    val t = i / 8.0f
                                    (0.08f + 0.28f * t * t)
                                }
                                "halo" -> {
                                    // Halo: center is lower, sides are higher
                                    val t = i / 8.0f
                                    (0.24f - 0.16f * Math.sin(t * Math.PI).toFloat())
                                }
                                else -> {
                                    // Gradient & Cut Crease: normal bell curve
                                    0.16f * bellFactor
                                }
                            }
                            
                            val shiftAmount = eyeDistance * shapeFactor
                            val sx = upperLid[i].x - screenUnitY.x * shiftAmount
                            val sy = upperLid[i].y - screenUnitY.y * shiftAmount
                            shiftedPoints.add(PointF(sx, sy))
                        }

                        eyeshadowPath.moveTo(upperLid[0].x, upperLid[0].y)
                        for (i in 1 until upperLid.size) {
                            eyeshadowPath.lineTo(upperLid[i].x, upperLid[i].y)
                        }
                        for (i in shiftedPoints.size - 1 downTo 0) {
                            eyeshadowPath.lineTo(shiftedPoints[i].x, shiftedPoints[i].y)
                        }
                        eyeshadowPath.close()

                        // Define colors based on shape
                        val baseAlpha = (eyeshadowOpacity * 255).toInt()
                        
                        val shader = when (eyeshadowShape) {
                            "gradient" -> {
                                // Linear horizontal gradient: inner corner to outer corner
                                val cStart = Color.argb((baseAlpha * 0.15f).toInt(), Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                val cEnd = Color.argb(baseAlpha, Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                LinearGradient(
                                    upperLid[0].x, upperLid[0].y,
                                    upperLid[8].x, upperLid[8].y,
                                    cStart, cEnd,
                                    Shader.TileMode.CLAMP
                                )
                            }
                            "cat_eye" -> {
                                // Cat eye: linear diagonal gradient towards outer top
                                val cStart = Color.argb(0, Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                val cEnd = Color.argb(baseAlpha, Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                LinearGradient(
                                    upperLid[0].x, upperLid[0].y,
                                    shiftedPoints[8].x, shiftedPoints[8].y,
                                    cStart, cEnd,
                                    Shader.TileMode.CLAMP
                                )
                            }
                            "halo" -> {
                                // Halo: outer & inner are dark, center is bright
                                val cDark = Color.argb(baseAlpha, Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                val cBright = Color.argb((baseAlpha * 0.3f).toInt(), Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                LinearGradient(
                                    upperLid[0].x, upperLid[0].y,
                                    upperLid[8].x, upperLid[8].y,
                                    intArrayOf(cDark, cBright, cDark),
                                    floatArrayOf(0.0f, 0.5f, 1.0f),
                                    Shader.TileMode.CLAMP
                                )
                            }
                            else -> {
                                // Standard / Cut Crease: vertical gradient
                                val colorStart = Color.argb(baseAlpha, Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                val colorEnd = Color.argb(0, Color.red(eyeshadowColor), Color.green(eyeshadowColor), Color.blue(eyeshadowColor))
                                LinearGradient(
                                    upperLid[4].x, upperLid[4].y,
                                    shiftedPoints[4].x, shiftedPoints[4].y,
                                    colorStart, colorEnd,
                                    Shader.TileMode.CLAMP
                                )
                            }
                        }

                        pathPaint.shader = shader
                        val blurSize = if (eyeshadowShape == "cut_crease") 4f else 15f
                        pathPaint.maskFilter = BlurMaskFilter(blurSize, BlurMaskFilter.Blur.NORMAL)
                        
                        val clipPath = Path()
                        clipPath.moveTo(upperLid[0].x, upperLid[0].y)
                        for (i in 1 until upperLid.size) {
                            clipPath.lineTo(upperLid[i].x, upperLid[i].y)
                        }
                        val farUp1 = PointF(
                            upperLid.last().x - screenUnitY.x * (eyeDistance * 2f),
                            upperLid.last().y - screenUnitY.y * (eyeDistance * 2f)
                        )
                        val farUp2 = PointF(
                            upperLid.first().x - screenUnitY.x * (eyeDistance * 2f),
                            upperLid.first().y - screenUnitY.y * (eyeDistance * 2f)
                        )
                        clipPath.lineTo(farUp1.x, farUp1.y)
                        clipPath.lineTo(farUp2.x, farUp2.y)
                        clipPath.close()

                        canvas.save()
                        canvas.clipPath(clipPath)
                        canvas.drawPath(eyeshadowPath, pathPaint)
                        canvas.restore()
                        
                        pathPaint.maskFilter = null
                        pathPaint.shader = null
                    }

                    // 2. EYELINER RENDER
                    if (hasEyeliner) {
                        val eyelinerPath = Path()
                        
                        var wingUnitX = screenUnitX
                        if (wingUnitX.x < 0f) {
                            wingUnitX = PointF(-wingUnitX.x, -wingUnitX.y)
                        }

                        val isP0OnLeft = upperLid[0].x < upperLid[8].x
                        val sortedUpperLid = if (isP0OnLeft) upperLid else upperLid.reversed()

                        val maxThickness = eyeDistance * 0.012f * (1.0f + eyelinerThickness * 2.5f)

                        val upperBoundary = ArrayList<PointF>()
                        for (i in 0 until sortedUpperLid.size) {
                            val t = if (isEyeOnLeftOfScreen) {
                                1.0f - (i.toFloat() / (sortedUpperLid.size - 1))
                            } else {
                                i.toFloat() / (sortedUpperLid.size - 1)
                            }
                            val shiftAmount = maxThickness * t
                            upperBoundary.add(PointF(
                                sortedUpperLid[i].x - screenUnitY.x * shiftAmount,
                                sortedUpperLid[i].y - screenUnitY.y * shiftAmount
                            ))
                        }

                        if (isEyeOnLeftOfScreen) {
                            val outerCorner = sortedUpperLid.first()
                            val wingX = outerCorner.x - wingUnitX.x * (eyeDistance * 0.08f) - screenUnitY.x * (eyeDistance * 0.015f)
                            val wingY = outerCorner.y - wingUnitX.y * (eyeDistance * 0.08f) - screenUnitY.y * (eyeDistance * 0.015f)

                            eyelinerPath.moveTo(wingX, wingY)
                            eyelinerPath.lineTo(upperBoundary.first().x, upperBoundary.first().y)
                            for (i in 1 until upperBoundary.size) {
                                eyelinerPath.lineTo(upperBoundary[i].x, upperBoundary[i].y)
                            }
                            for (i in sortedUpperLid.size - 1 downTo 0) {
                                eyelinerPath.lineTo(sortedUpperLid[i].x, sortedUpperLid[i].y)
                            }
                            eyelinerPath.close()
                        } else {
                            val outerCorner = sortedUpperLid.last()
                            val wingX = outerCorner.x + wingUnitX.x * (eyeDistance * 0.08f) - screenUnitY.x * (eyeDistance * 0.015f)
                            val wingY = outerCorner.y + wingUnitX.y * (eyeDistance * 0.08f) - screenUnitY.y * (eyeDistance * 0.015f)

                            eyelinerPath.moveTo(sortedUpperLid.first().x, sortedUpperLid.first().y)
                            for (i in 0 until upperBoundary.size) {
                                eyelinerPath.lineTo(upperBoundary[i].x, upperBoundary[i].y)
                            }
                            eyelinerPath.lineTo(wingX, wingY)
                            for (i in sortedUpperLid.size - 1 downTo 0) {
                                eyelinerPath.lineTo(sortedUpperLid[i].x, sortedUpperLid[i].y)
                            }
                            eyelinerPath.close()
                        }

                        val eyelinerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            style = Paint.Style.FILL
                            color = 0xFF1A1A1A.toInt()
                            maskFilter = BlurMaskFilter(0.8f, BlurMaskFilter.Blur.NORMAL)
                        }
                        canvas.drawPath(eyelinerPath, eyelinerPaint)
                    }
                }

                if (leftScreenEye != null && rightScreenEye != null) {
                    val isLeftEyeOnLeft = leftScreenEye.x < rightScreenEye.x
                    drawEyeMakeup(leftEye, isLeftEyeOnLeft)
                    drawEyeMakeup(rightEye, !isLeftEyeOnLeft)
                }
            }
        }

        // 3. Blush-on - Oval draping mapping with dynamic rotation, roll, and tilt based on face aspect ratio (Wajah Bulat, Oval, Lonjong)
        if (blushColor != Color.TRANSPARENT && blushOpacity > 0f) {
            val faceWidth = currentFace.boundingBox.width().toFloat() * scale
            val blushRadius = faceWidth * 0.16f

            canvas.save()
            // Clip to face contour path to keep blush-on within the face boundaries
            val faceOutline = getSmoothedContour(currentFace, FaceContour.FACE)
            if (faceOutline != null && faceOutline.isNotEmpty()) {
                val facePath = Path()
                val start = mapPoint(faceOutline[0])
                facePath.moveTo(start.x, start.y)
                for (i in 1 until faceOutline.size) {
                    val pt = mapPoint(faceOutline[i])
                    facePath.lineTo(pt.x, pt.y)
                }
                facePath.close()
                canvas.clipPath(facePath)
            }

            val cheeks = getCheekboneCoordinates(currentFace)
            val leftCheekCenterRaw = cheeks["left"] ?: PointF(0f, 0f)
            val rightCheekCenterRaw = cheeks["right"] ?: PointF(0f, 0f)

            val leftCheek = mapPoint(leftCheekCenterRaw)
            val rightCheek = mapPoint(rightCheekCenterRaw)

            fun drawCheekBlush(center: PointF, isLeft: Boolean) {
                val rollAngle = (currentFace.headEulerAngleZ ?: 0f) * Math.PI.toFloat() / 180f
                val smileProb = currentFace.smilingProbability ?: 0f
                val smileShiftY = smileProb * blushRadius * 0.25f

                canvas.save()
                canvas.translate(center.x, center.y)

                val boxW = currentFace.boundingBox.width().toFloat()
                val boxH = currentFace.boundingBox.height().toFloat()
                val ratio = boxH / boxW

                val tilt: Float
                val blushW: Float
                val blushH: Float

                if (ratio < 1.13f) {
                    // Wajah bulat/lebar: sapuan sangat miring (tirus) ke atas
                    tilt = if (isLeft) -0.32f else 0.32f
                    blushW = faceWidth * 0.54f
                    blushH = faceWidth * 0.23f
                } else if (ratio > 1.25f) {
                    // Wajah lonjong/panjang: sapuan mendatar (horizontal)
                    tilt = 0.0f
                    blushW = faceWidth * 0.56f
                    blushH = faceWidth * 0.28f
                } else {
                    // Wajah oval (default)
                    tilt = if (isLeft) -0.20f else 0.20f
                    blushW = faceWidth * 0.54f
                    blushH = faceWidth * 0.26f
                }

                val rollCorrection = if (isFrontCamera) rollAngle else -rollAngle
                val tiltCorrection = if (isFrontCamera) tilt else -tilt
                canvas.rotate((rollCorrection + tiltCorrection) * 180f / Math.PI.toFloat())

                // Outward offset with front-camera mirroring reflection accounted for
                // Front camera is mirrored, so left/right are flipped relative to screen
                val offsetX = if (isLeft) {
                    if (isFrontCamera) blushW * 0.20f else -blushW * 0.20f
                } else {
                    if (isFrontCamera) -blushW * 0.20f else blushW * 0.20f
                }

                val rect = RectF(
                    offsetX - blushW / 2f,
                    -smileShiftY - blushH / 2f,
                    offsetX + blushW / 2f,
                    -smileShiftY + blushH / 2f
                )

                // Use standard blending with custom RadialGradient and BlurMaskFilter to avoid transparent canvas composition issues
                val blushPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    maskFilter = BlurMaskFilter(blushRadius * 0.9f, BlurMaskFilter.Blur.NORMAL)
                    
                    // Radial gradient shader
                    val c1 = Color.argb((blushOpacity * 255).toInt().coerceAtMost(255), Color.red(blushColor), Color.green(blushColor), Color.blue(blushColor))
                    val c2 = Color.argb((blushOpacity * 120).toInt().coerceAtMost(255), Color.red(blushColor), Color.green(blushColor), Color.blue(blushColor))
                    val c3 = Color.TRANSPARENT
                    
                    shader = android.graphics.RadialGradient(
                        rect.centerX(),
                        rect.centerY(),
                        Math.max(blushW, blushH) / 2f,
                        intArrayOf(c1, c2, c3),
                        floatArrayOf(0.0f, 0.5f, 1.0f),
                        android.graphics.Shader.TileMode.CLAMP
                    )
                }

                canvas.drawOval(rect, blushPaint)
                canvas.restore()
            }

            drawCheekBlush(leftCheek, true)
            drawCheekBlush(rightCheek, false)

            canvas.restore()
        }

        // 4. Lipstick (Bibir)
        if (lipstickColor != Color.TRANSPARENT && lipstickOpacity > 0f) {
            val upperLipTop = getSmoothedContour(currentFace, FaceContour.UPPER_LIP_TOP)
            val upperLipBottom = getSmoothedContour(currentFace, FaceContour.UPPER_LIP_BOTTOM)
            val lowerLipTop = getSmoothedContour(currentFace, FaceContour.LOWER_LIP_TOP)
            val lowerLipBottom = getSmoothedContour(currentFace, FaceContour.LOWER_LIP_BOTTOM)

            val rawUpperTop = currentFace.getContour(FaceContour.UPPER_LIP_TOP)?.points
            val rawUpperBottom = currentFace.getContour(FaceContour.UPPER_LIP_BOTTOM)?.points
            val rawLowerTop = currentFace.getContour(FaceContour.LOWER_LIP_TOP)?.points
            val rawLowerBottom = currentFace.getContour(FaceContour.LOWER_LIP_BOTTOM)?.points

            if (upperLipTop != null && upperLipTop.isNotEmpty() &&
                upperLipBottom != null && upperLipBottom.isNotEmpty() &&
                lowerLipTop != null && lowerLipTop.isNotEmpty() &&
                lowerLipBottom != null && lowerLipBottom.isNotEmpty() &&
                rawUpperTop != null && rawUpperTop.isNotEmpty() &&
                rawUpperBottom != null && rawUpperBottom.isNotEmpty() &&
                rawLowerTop != null && rawLowerTop.isNotEmpty() &&
                rawLowerBottom != null && rawLowerBottom.isNotEmpty()) {

                // Calculate raw thickness for instantaneous expressionScale (no lag/smoothing delay)
                val rawMidUpperTop = mapPoint(rawUpperTop[rawUpperTop.size / 2])
                val rawMidUpperBottom = mapPoint(rawUpperBottom[rawUpperBottom.size / 2])
                val rawMidLowerTop = mapPoint(rawLowerTop[rawLowerTop.size / 2])
                val rawMidLowerBottom = mapPoint(rawLowerBottom[rawLowerBottom.size / 2])

                val rawUpperThickness = Math.abs(rawMidUpperBottom.y - rawMidUpperTop.y)
                val rawLowerThickness = Math.abs(rawMidLowerBottom.y - rawMidLowerTop.y)
                val rawUpperRatio = if (eyeDistance > 0f) (rawUpperThickness / eyeDistance) else 0.03f
                val rawLowerRatio = if (eyeDistance > 0f) (rawLowerThickness / eyeDistance) else 0.04f
                val rawAvgThickness = (rawUpperRatio + rawLowerRatio) / 2f

                // Calculate mouth ratio using smoothed coordinates for stable mouth openness scaling
                val midTop = mapPoint(upperLipTop[upperLipTop.size / 2])
                val midBottom = mapPoint(lowerLipBottom[lowerLipBottom.size / 2])
                val mouthHeight = Math.abs(midBottom.y - midTop.y)
                val mouthRatio = if (eyeDistance > 0f) (mouthHeight / eyeDistance) else 0.12f
                val mouthOpenness = ((mouthRatio - 0.11f) / 0.08f).coerceIn(0f, 1f)

                // Self-calibrating maximum lip thickness tracker (scale-independent)
                if (rawAvgThickness > maxLipThicknessRatio && rawAvgThickness < 0.07f && mouthOpenness < 0.15f) {
                    maxLipThicknessRatio = rawAvgThickness
                }
                // Decay max lip thickness slowly to adapt to user repositioning
                maxLipThicknessRatio = (maxLipThicknessRatio * 0.995f + rawAvgThickness * 0.005f).coerceIn(0.028f, 0.070f)

                val relativeThickness = rawAvgThickness / maxLipThicknessRatio
                // If relativeThickness drops below 0.70 (meaning lip thickness drops by >30%), fade out completely
                val expressionScale = ((relativeThickness - 0.70f) / 0.18f).coerceIn(0f, 1f)

                // Decouple expansionFactor from expressionScale and keep baseExpansion at 1.09f
                val baseExpansion = 1.09f
                val expansionFactor = 1.0f + (baseExpansion - 1.0f) * (1f - mouthOpenness)

                fun drawLipPath(top: List<PointF>?, bottom: List<PointF>?) {
                    if (top == null || top.isEmpty() || bottom == null || bottom.isEmpty() || expressionScale <= 0f) return

                    val centroidRaw = getPathCentroid(top, bottom)
                    val centroid = mapPoint(centroidRaw)

                    val expandedTop = top.map { rawPt ->
                        val pt = mapPoint(rawPt)
                        PointF(
                            pt.x, // Lock horizontal mapping exactly to detected corners
                            centroid.y + (pt.y - centroid.y) * expansionFactor // Vertical expansion only
                        )
                    }
                    val expandedBottom = bottom.map { rawPt ->
                        val pt = mapPoint(rawPt)
                        PointF(
                            pt.x, // Lock horizontal mapping exactly to detected corners
                            centroid.y + (pt.y - centroid.y) * expansionFactor // Vertical expansion only
                        )
                    }

                    val path = Path()
                    path.moveTo(expandedTop[0].x, expandedTop[0].y)
                    for (i in 1 until expandedTop.size) {
                        path.lineTo(expandedTop[i].x, expandedTop[i].y)
                    }
                    for (i in expandedBottom.size - 1 downTo 0) {
                        path.lineTo(expandedBottom[i].x, expandedBottom[i].y)
                    }
                    path.close()

                    pathPaint.color = lipstickColor
                    pathPaint.maskFilter = BlurMaskFilter(2f, BlurMaskFilter.Blur.NORMAL)

                    when (lipstickFinishing) {
                        "glossy" -> {
                            pathPaint.xfermode = null
                            pathPaint.alpha = (lipstickOpacity * 240 * expressionScale).toInt()
                            canvas.drawPath(path, pathPaint)

                            val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                                style = Paint.Style.STROKE
                                color = Color.WHITE
                                alpha = (lipstickOpacity * 110 * expressionScale).toInt()
                                strokeWidth = 2.5f
                                maskFilter = BlurMaskFilter(3f, BlurMaskFilter.Blur.NORMAL)
                            }
                            canvas.drawPath(path, highlightPaint)
                        }
                        "liquid_matte" -> {
                            pathPaint.xfermode = null
                            pathPaint.alpha = (lipstickOpacity * 250 * expressionScale).toInt()
                            pathPaint.maskFilter = BlurMaskFilter(1f, BlurMaskFilter.Blur.NORMAL)
                            canvas.drawPath(path, pathPaint)
                        }
                        "blurred_matte" -> {
                            pathPaint.xfermode = null
                            pathPaint.alpha = (lipstickOpacity * 175 * expressionScale).toInt()
                            pathPaint.maskFilter = BlurMaskFilter(3.5f, BlurMaskFilter.Blur.NORMAL)
                            canvas.drawPath(path, pathPaint)

                            val scaleFactor = 0.72f
                            val innerPath = Path()
                            val startX = centroid.x + (expandedTop[0].x - centroid.x) * scaleFactor
                            val startY = centroid.y + (expandedTop[0].y - centroid.y) * scaleFactor
                            innerPath.moveTo(startX, startY)
                            for (i in 1 until expandedTop.size) {
                                val px = centroid.x + (expandedTop[i].x - centroid.x) * scaleFactor
                                val py = centroid.y + (expandedTop[i].y - centroid.y) * scaleFactor
                                innerPath.lineTo(px, py)
                            }
                            for (i in expandedBottom.size - 1 downTo 0) {
                                val px = centroid.x + (expandedBottom[i].x - centroid.x) * scaleFactor
                                val py = centroid.y + (expandedBottom[i].y - centroid.y) * scaleFactor
                                innerPath.lineTo(px, py)
                            }
                            innerPath.close()

                            pathPaint.xfermode = null
                            pathPaint.alpha = (lipstickOpacity * 205 * expressionScale).toInt()
                            pathPaint.maskFilter = BlurMaskFilter(5.5f, BlurMaskFilter.Blur.NORMAL)
                            canvas.drawPath(innerPath, pathPaint)
                        }
                        else -> {
                            pathPaint.xfermode = null
                            pathPaint.alpha = (lipstickOpacity * 185 * expressionScale).toInt()
                            pathPaint.maskFilter = BlurMaskFilter(2.8f, BlurMaskFilter.Blur.NORMAL)
                            canvas.drawPath(path, pathPaint)
                        }
                    }
                    pathPaint.maskFilter = null
                    pathPaint.xfermode = null
                }

                if (upperLipTop != null && upperLipBottom != null) {
                    drawLipPath(upperLipTop, upperLipBottom)
                }
                if (lowerLipTop != null && lowerLipBottom != null) {
                    drawLipPath(lowerLipTop, lowerLipBottom)
                }
            }
        }

        // 5. Nose Contour & Highlight (Shading & Highlight)
        if (noseHighlightOpacity > 0f || noseShadingOpacity > 0f) {
            val noseBridgePoints = currentFace.getContour(FaceContour.NOSE_BRIDGE)?.points
            if (noseBridgePoints != null && noseBridgePoints.isNotEmpty() && eyeDistance > 0f) {
                val mappedBridge = noseBridgePoints.map { mapPoint(it) }
                val faceWidth = currentFace.boundingBox.width().toFloat() * scale
                val strokeW = faceWidth * 0.024f

                // 1. NOSE SHADING (CONTOUR)
                if (noseShadingOpacity > 0f) {
                    val leftShadingPath = Path()
                    val rightShadingPath = Path()
                    val sideShift = faceWidth * 0.040f // distance from center line to sides

                    leftShadingPath.moveTo(
                        mappedBridge.first().x - screenUnitX.x * sideShift,
                        mappedBridge.first().y - screenUnitX.y * sideShift
                    )
                    rightShadingPath.moveTo(
                        mappedBridge.first().x + screenUnitX.x * sideShift,
                        mappedBridge.first().y + screenUnitX.y * sideShift
                    )

                    for (i in 1 until mappedBridge.size) {
                        leftShadingPath.lineTo(
                            mappedBridge[i].x - screenUnitX.x * sideShift,
                            mappedBridge[i].y - screenUnitX.y * sideShift
                        )
                        rightShadingPath.lineTo(
                            mappedBridge[i].x + screenUnitX.x * sideShift,
                            mappedBridge[i].y + screenUnitX.y * sideShift
                        )
                    }

                     val paintShading = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        color = Color.parseColor("#5A4D46") // Cool-toned taupe/grey-brown
                        alpha = (noseShadingOpacity * 0.75f * 255f).toInt().coerceIn(0, 255)
                        strokeWidth = faceWidth * 0.038f
                        strokeCap = Paint.Cap.ROUND
                        strokeJoin = Paint.Join.ROUND
                        maskFilter = BlurMaskFilter(15f, BlurMaskFilter.Blur.NORMAL)
                    }

                    canvas.drawPath(leftShadingPath, paintShading)
                    canvas.drawPath(rightShadingPath, paintShading)

                    // Draw Nose Tip V septum shape for shortening illusion
                    val noseTipVPath = Path().apply {
                        val tip = mappedBridge.last()
                        val vWidth = faceWidth * 0.040f
                        val vHeight = faceWidth * 0.022f
                        moveTo(tip.x - vWidth, tip.y - vHeight)
                        lineTo(tip.x, tip.y + vHeight * 0.4f)
                        lineTo(tip.x + vWidth, tip.y - vHeight)
                    }
                    canvas.drawPath(noseTipVPath, paintShading)
                }

                // 2. NOSE HIGHLIGHT
                if (noseHighlightOpacity > 0f) {
                    val highlightPath = Path()
                    highlightPath.moveTo(mappedBridge.first().x, mappedBridge.first().y)
                    for (i in 1 until mappedBridge.size - 1) {
                        highlightPath.lineTo(mappedBridge[i].x, mappedBridge[i].y)
                    }

                    val paintHighlightLine = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.STROKE
                        color = Color.parseColor("#FFFDF5")
                        alpha = (noseHighlightOpacity * 0.5f * 255f).toInt().coerceIn(0, 255)
                        strokeWidth = strokeW
                        strokeCap = Paint.Cap.ROUND
                        maskFilter = BlurMaskFilter(8f, BlurMaskFilter.Blur.NORMAL)
                    }

                    canvas.drawPath(highlightPath, paintHighlightLine)

                    val noseTip = mappedBridge.last()
                    val paintTipCircle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        style = Paint.Style.FILL
                        color = Color.parseColor("#FFFDF5")
                        alpha = (noseHighlightOpacity * 0.65f * 255f).toInt().coerceIn(0, 255)
                        maskFilter = BlurMaskFilter(8f, BlurMaskFilter.Blur.NORMAL)
                    }

                    canvas.drawCircle(noseTip.x, noseTip.y, faceWidth * 0.009f, paintTipCircle)
                }
            }
        }

        // 6. Face Shape & Contour Guidance guidelines (Contour Guide)
        if (showContourGuide && eyeDistance > 0f) {
            val shape = classifyFaceShape(currentFace)
            val faceContour = currentFace.getContour(FaceContour.FACE)?.points ?: emptyList()

            if (faceContour.size >= 36) {
                val contourFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = Color.parseColor("#3B8B5A2B") // Brown 23% opacity
                }

                val contourStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 4f
                    color = Color.parseColor("#808B5A2B") // Brown 50% opacity
                }

                val highlightFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.FILL
                    color = Color.parseColor("#3BFFEB3B") // Golden yellow 23% opacity
                }

                val highlightStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = 4f
                    color = Color.parseColor("#80FFEB3B") // Golden yellow 50% opacity
                }

                fun drawOvalGuide(center: PointF, rx: Float, ry: Float, isHighlight: Boolean) {
                    val centerOffset = mapPoint(center)
                    val rollRad = ((currentFace.headEulerAngleZ ?: 0f) * Math.PI / 180f).toFloat()

                    canvas.save()
                    canvas.translate(centerOffset.x, centerOffset.y)
                    // Mirror reflection camera rotation correction
                    val rollCorrection = if (isFrontCamera) -rollRad else rollRad
                    canvas.rotate(rollCorrection * 180f / Math.PI.toFloat())

                    val rect = RectF(-rx * scale, -ry * scale, rx * scale, ry * scale)
                    canvas.drawOval(rect, if (isHighlight) highlightFillPaint else contourFillPaint)
                    canvas.drawOval(rect, if (isHighlight) highlightStrokePaint else contourStrokePaint)

                    canvas.restore()
                }

                val leftCenter = getEyeCenter(leftEyeContour ?: emptyList())
                val rightCenter = getEyeCenter(rightEyeContour ?: emptyList())

                val vectors = getFaceUnitVectors(currentFace, leftCenter, rightCenter)
                val unitX = vectors["unitX"]!!
                val unitY = vectors["unitY"]!!
                val eyeDist = vectors["distance"]!!.x

                val cheekCoords = getCheekboneCoordinates(currentFace)
                val foreheadPoints = getHairlinePoints(currentFace)
                val foreheadPt = foreheadPoints[1] // The center forehead point

                // --- DRAW COMMON HIGHLIGHTS ---
                // 1. Dahi Tengah (Center Forehead)
                drawOvalGuide(foreheadPt, eyeDist * 0.22f, eyeDist * 0.12f, true)

                // 2. Batang Hidung (Nose Bridge)
                val noseBridgePoints = currentFace.getContour(FaceContour.NOSE_BRIDGE)?.points ?: emptyList()
                if (noseBridgePoints.isNotEmpty()) {
                    val noseCenter = noseBridgePoints[noseBridgePoints.size / 2]
                    drawOvalGuide(noseCenter, eyeDist * 0.08f, eyeDist * 0.35f, true)
                }

                // 3. Dagu Tengah (Chin center)
                val chinPoint = faceContour[18]
                val chinShifted = PointF(
                    chinPoint.x - unitY.x * (eyeDist * 0.12f),
                    chinPoint.y - unitY.y * (eyeDist * 0.12f)
                )
                drawOvalGuide(chinShifted, eyeDist * 0.12f, eyeDist * 0.08f, true)

                // --- DRAW SHAPE-SPECIFIC CONTOURS & HIGHLIGHTS ---
                if (shape == "round") {
                    val cpLeft = PointF(
                        cheekCoords["left"]!!.x + unitY.x * (eyeDist * 0.18f) - unitX.x * (eyeDist * 0.12f),
                        cheekCoords["left"]!!.y + unitY.y * (eyeDist * 0.18f) - unitX.y * (eyeDist * 0.12f)
                    )
                    drawOvalGuide(cpLeft, eyeDist * 0.28f, eyeDist * 0.10f, false)

                    val cpRight = PointF(
                        cheekCoords["right"]!!.x + unitY.x * (eyeDist * 0.18f) + unitX.x * (eyeDist * 0.12f),
                        cheekCoords["right"]!!.y + unitY.y * (eyeDist * 0.18f) + unitX.y * (eyeDist * 0.12f)
                    )
                    drawOvalGuide(cpRight, eyeDist * 0.28f, eyeDist * 0.10f, false)

                    val templeLeft = PointF(
                        leftCenter.x - unitX.x * (eyeDist * 0.35f) - unitY.x * (eyeDist * 0.5f),
                        leftCenter.y - unitX.y * (eyeDist * 0.35f) - unitY.y * (eyeDist * 0.5f)
                    )
                    drawOvalGuide(templeLeft, eyeDist * 0.15f, eyeDist * 0.10f, false)

                    val templeRight = PointF(
                        rightCenter.x + unitX.x * (eyeDist * 0.35f) - unitY.x * (eyeDist * 0.5f),
                        rightCenter.y + unitX.y * (eyeDist * 0.35f) - unitY.y * (eyeDist * 0.5f)
                    )
                    drawOvalGuide(templeRight, eyeDist * 0.15f, eyeDist * 0.10f, false)

                } else if (shape == "square") {
                    val jawLeft = faceContour[12]
                    val jawLeftShifted = PointF(
                        jawLeft.x - (unitX.x * (eyeDist * 0.1f) - unitY.x * (eyeDist * 0.1f)),
                        jawLeft.y - (unitX.y * (eyeDist * 0.1f) - unitY.y * (eyeDist * 0.1f))
                    )
                    drawOvalGuide(jawLeftShifted, eyeDist * 0.25f, eyeDist * 0.15f, false)

                    val jawRight = faceContour[24]
                    val jawRightShifted = PointF(
                        jawRight.x + (unitX.x * (eyeDist * 0.1f) + unitY.x * (eyeDist * 0.1f)),
                        jawRight.y + (unitX.y * (eyeDist * 0.1f) + unitY.y * (eyeDist * 0.1f))
                    )
                    drawOvalGuide(jawRightShifted, eyeDist * 0.25f, eyeDist * 0.15f, false)

                    val foreheadCornerLeft = faceContour[4]
                    drawOvalGuide(foreheadCornerLeft, eyeDist * 0.2f, eyeDist * 0.12f, false)

                    val foreheadCornerRight = faceContour[32]
                    drawOvalGuide(foreheadCornerRight, eyeDist * 0.2f, eyeDist * 0.12f, false)

                } else if (shape == "heart") {
                    val dahiLeft = faceContour[3]
                    drawOvalGuide(dahiLeft, eyeDist * 0.22f, eyeDist * 0.12f, false)

                    val dahiRight = faceContour[33]
                    drawOvalGuide(dahiRight, eyeDist * 0.22f, eyeDist * 0.12f, false)

                    drawOvalGuide(chinPoint, eyeDist * 0.15f, eyeDist * 0.08f, false)

                    val jawLeftMid = faceContour[14]
                    drawOvalGuide(jawLeftMid, eyeDist * 0.15f, eyeDist * 0.08f, true)

                    val jawRightMid = faceContour[22]
                    drawOvalGuide(jawRightMid, eyeDist * 0.15f, eyeDist * 0.08f, true)

                } else if (shape == "long") {
                    val fhCenter = faceContour[0]
                    drawOvalGuide(fhCenter, eyeDist * 0.45f, eyeDist * 0.10f, false)

                    drawOvalGuide(chinPoint, eyeDist * 0.35f, eyeDist * 0.12f, false)

                    drawOvalGuide(cheekCoords["left"]!!, eyeDist * 0.20f, eyeDist * 0.08f, true)
                    drawOvalGuide(cheekCoords["right"]!!, eyeDist * 0.20f, eyeDist * 0.08f, true)

                } else { // oval
                    val cpLeft = PointF(
                        cheekCoords["left"]!!.x + unitY.x * (eyeDist * 0.15f) - unitX.x * (eyeDist * 0.10f),
                        cheekCoords["left"]!!.y + unitY.y * (eyeDist * 0.15f) - unitX.y * (eyeDist * 0.10f)
                    )
                    drawOvalGuide(cpLeft, eyeDist * 0.24f, eyeDist * 0.08f, false)

                    val cpRight = PointF(
                        cheekCoords["right"]!!.x + unitY.x * (eyeDist * 0.15f) + unitX.x * (eyeDist * 0.10f),
                        cheekCoords["right"]!!.y + unitY.y * (eyeDist * 0.15f) + unitX.y * (eyeDist * 0.10f)
                    )
                    drawOvalGuide(cpRight, eyeDist * 0.24f, eyeDist * 0.08f, false)
                }
            }
        }

        canvas.restore();
    }
}
