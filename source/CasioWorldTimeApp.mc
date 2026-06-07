using Toybox.Application as App;
using Toybox.WatchUi as Ui;

// Application entry point. For a watch face the only job here is to hand
// Connect IQ our single View when the system asks for the initial layout.
class CasioWorldTimeApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    // Return the watch face view (and no input delegate -- watch faces
    // do not receive taps while on the face).
    function getInitialView() {
        return [ new CasioWorldTimeView() ];
    }

    // Re-render immediately when the user changes settings in Garmin Connect.
    function onSettingsChanged() {
        Ui.requestUpdate();
    }
}
