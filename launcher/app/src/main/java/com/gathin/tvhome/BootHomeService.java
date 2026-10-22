package com.gathin.tvhome;

import android.accessibilityservice.AccessibilityService;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

/**
 * Brings Home back when the TV's own Live TV app starts by itself right after a cold boot.
 *
 * On Philips/TP Vision sets (org.droidtv.playtv) the Live TV app always restarts after a full power-off
 * and retunes the last source; the firmware has no setting for it (PlayTvBroadcastReceiver starts
 * org.droidtv.playtv.BOOTCOMPLETED unconditionally outside the first-setup "virgin" modes). This service
 * watches only that package, only during the first {@link #BOOT_WINDOW_MS} after boot, and presses Home
 * once. Waking from quick standby does not reset the uptime clock, so it never acts then, and Live TV
 * opened later from Inputs is left alone.
 *
 * Opt-in; enable over adb:
 *   settings put secure enabled_accessibility_services com.gathin.tvhome/.BootHomeService
 *   settings put secure accessibility_enabled 1
 * (append to an existing list with ':' instead of replacing it).
 */
public class BootHomeService extends AccessibilityService {

    static final String LIVE_TV = "org.droidtv.playtv";
    /** Time since boot during which a Live TV window counts as "started by itself". */
    static final long BOOT_WINDOW_MS = 120_000L;
    /** Let Live TV finish taking the screen before Home is pressed, or it can come back on top. */
    private static final long HOME_DELAY_MS = 2_500L;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean done;

    static boolean shouldSendHome(String pkg, long uptimeMs, boolean alreadyDone) {
        return !alreadyDone && LIVE_TV.equals(pkg) && uptimeMs < BOOT_WINDOW_MS;
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        // Live TV usually starts before accessibility services are bound: look at what is in front now.
        AccessibilityNodeInfo root = getRootInActiveWindow();
        CharSequence pkg = root != null ? root.getPackageName() : null;
        consider(pkg != null ? pkg.toString() : null);
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return;
        CharSequence pkg = event.getPackageName();
        consider(pkg != null ? pkg.toString() : null);
    }

    private void consider(String pkg) {
        if (!shouldSendHome(pkg, SystemClock.elapsedRealtime(), done)) return;
        done = true;
        handler.postDelayed(() -> performGlobalAction(GLOBAL_ACTION_HOME), HOME_DELAY_MS);
    }

    @Override
    public void onInterrupt() {
    }
}
