import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool dashboardNotch // Small notch with the dashboard tab buttons, opened on hover
    property bool utilities
    property bool sidebar

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
