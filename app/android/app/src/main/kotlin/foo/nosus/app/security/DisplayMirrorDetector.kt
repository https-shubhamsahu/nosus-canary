package foo.nosus.app.security

import android.content.Context
import android.hardware.display.DisplayManager
import android.view.Display

/**
 * Flags additional displays (wired HDMI/DisplayPort, wireless
 * Miracast mirroring, or a Cast "presentation" virtual display) beyond the
 * device's own built-in screen. This is checked per viewing session (see
 * DeviceIntegrityService.runViewingChecks) rather than once at launch,
 * since mirroring can start after a document is already open.
 */
object DisplayMirrorDetector {

    fun scan(context: Context): Map<String, Any?> {
        val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays
        val external = displays.filter { it.displayId != Display.DEFAULT_DISPLAY }

        val info = external.map { display ->
            mapOf(
                "id" to display.displayId,
                "name" to display.name,
                "isPresentation" to ((display.flags and Display.FLAG_PRESENTATION) != 0)
            )
        }

        return mapOf(
            "mirroring" to external.isNotEmpty(),
            "displays" to info
        )
    }
}
