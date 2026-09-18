package foo.nosus.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Registers the notification channels that `supabase/functions/send-push`
 * addresses by id.
 *
 * This is load-bearing, not cosmetic. On Android 8+ a notification whose
 * `channel_id` does not exist on the device is **dropped silently** — no error,
 * no fallback, nothing on screen. send-push sets
 * `android.notification.channel_id` to `nosus_<category>`, so without these
 * every push would vanish and look like a broken FCM setup.
 *
 * Done in Kotlin rather than by adding flutter_local_notifications: channel
 * creation is a dozen lines of platform API, and the plugin would be a new
 * dependency carrying a whole local-notification stack this app does not
 * otherwise use.
 *
 * Creating channels needs no permission and is safe with no Firebase project
 * configured — the channels simply sit unused. Re-creating an existing channel
 * is a no-op, so calling this on every launch is correct and lets a later
 * release add a channel without any migration step.
 *
 * Note: name and importance are only honoured on first creation. Android hands
 * channel settings to the user after that, deliberately, and an app cannot take
 * them back. Renaming a channel means shipping a new id.
 */
object NotificationChannels {

    /** Must match the `category` CHECK constraint on `public.notifications`. */
    private val CHANNELS = listOf(
        ChannelSpec(
            id = "nosus_security",
            name = "Security alerts",
            description = "Access revoked, unusual sign-ins, and integrity warnings.",
            importance = NotificationManager.IMPORTANCE_HIGH,
        ),
        ChannelSpec(
            id = "nosus_invites",
            name = "Invites and requests",
            description = "Group invitations and requests to join groups you administer.",
            importance = NotificationManager.IMPORTANCE_DEFAULT,
        ),
        ChannelSpec(
            id = "nosus_membership",
            name = "Membership and roles",
            description = "Changes to your groups and your role in them.",
            importance = NotificationManager.IMPORTANCE_DEFAULT,
        ),
        ChannelSpec(
            id = "nosus_documents",
            name = "Document activity",
            description = "New documents shared in your groups.",
            importance = NotificationManager.IMPORTANCE_LOW,
        ),
        // Backstop for the default channel declared in AndroidManifest.xml,
        // which catches any message that arrives without a channel id.
        ChannelSpec(
            id = "nosus_general",
            name = "General",
            description = "Everything else.",
            importance = NotificationManager.IMPORTANCE_DEFAULT,
        ),
    )

    fun register(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        for (spec in CHANNELS) {
            val channel = NotificationChannel(spec.id, spec.name, spec.importance).apply {
                description = spec.description
                // Notification *content* already names no document and no group
                // (see enqueue_notification), but setting this explicitly means
                // a future payload change cannot start leaking onto a locked
                // screen without someone also changing this line.
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            }
            manager.createNotificationChannel(channel)
        }
    }

    private data class ChannelSpec(
        val id: String,
        val name: String,
        val description: String,
        val importance: Int,
    )
}
