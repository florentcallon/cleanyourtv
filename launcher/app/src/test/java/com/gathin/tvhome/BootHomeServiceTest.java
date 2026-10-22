package com.gathin.tvhome;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class BootHomeServiceTest {

    @Test
    public void liveTvRightAfterBootGoesHome() {
        assertTrue(BootHomeService.shouldSendHome("org.droidtv.playtv", 25_000L, false));
    }

    @Test
    public void onlyOncePerBoot() {
        assertFalse(BootHomeService.shouldSendHome("org.droidtv.playtv", 25_000L, true));
    }

    @Test
    public void liveTvOpenedLaterIsLeftAlone() {
        assertFalse(BootHomeService.shouldSendHome("org.droidtv.playtv", BootHomeService.BOOT_WINDOW_MS + 1, false));
    }

    @Test
    public void otherAppsAreIgnored() {
        assertFalse(BootHomeService.shouldSendHome("com.crunchyroll.crunchyroid", 25_000L, false));
        assertFalse(BootHomeService.shouldSendHome(null, 25_000L, false));
    }
}
