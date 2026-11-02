/// What to do instead, per rule. Only the correct practice: these texts must
/// not describe how a report could be silenced.
String guidanceFor(String rule, String detail) {
  switch (rule) {
    case 'public-api':
      return 'do not add public API; build it from the existing components, '
          'or keep the symbol private with a leading underscore';
    case 'layers':
      if (detail == 'unknown directory') {
        return 'place the file in one of the layer directories: foundation, '
            'primitives, motion, surface, controls, display, feedback, lists, '
            'overlays, layout, media, navigation or social';
      }
      if (detail.startsWith('frost_ui:')) {
        return 'use frost_ui through its public entries, or take the value as '
            'a parameter; unexported symbols stay inside frost_ui';
      }
      if (detail.startsWith('frost_data:')) {
        return 'frost_ui never depends on frost_data, and frost_data source '
            'imports the defining file, not its own entry';
      }
      return 'import only from the same layer or a lower one (foundation, '
          'then primitives/motion/surface, then controls/display/feedback/'
          'lists/overlays/layout/media, then navigation/social); move the '
          'shared piece down a layer or take it as a parameter';
    case 'framework':
      return switch (detail) {
        'highlightStrategy=' =>
          'do not set the focus highlight mode for the whole app; style focus '
              'from the Focus widget of the component itself',
        'addEarlyKeyEventHandler' ||
        'addLateKeyEventHandler' ||
        'HardwareKeyboard.addHandler' =>
          'handle keys with Shortcuts, Actions or a Focus onKeyEvent inside '
              'the component subtree, not with a global key handler',
        'pointerRouter' ||
        'hitTestInView' =>
          'react to pointers with a Listener or gesture recognizer in the '
              'component subtree, not through the global pointer router or hit test',
        'hitTest' =>
          'shape hits with hitTestChildren, hitTestSelf or a widget in the '
              'component subtree, not by overriding the whole hit test',
        'visitAncestorElements' ||
        'visitChildElements' =>
          'read what you need from an InheritedWidget instead of walking the '
              'element tree',
        'MediaQuery.size' =>
          'leave MediaQuery as the app provides it; lay out from the '
              'constraints the parent passes down',
        'MaterialScrollBehavior' =>
          'leave scroll behavior to the app; the library does not subclass it',
        _ => 'keep framework-wide behavior out of the library',
      };
    case 'basis':
      return switch (detail) {
        'FrostSizeClass' ||
        'MediaQuery.size' =>
          'decide from the constraints the parent passes down (LayoutBuilder) '
              'or from an explicit parameter, not from the window size',
        _ => 'decide from an explicit input capability or parameter, not from '
            'the platform name',
      };
    case 'child-type':
      return 'do not branch on the type of a child; take the behavior as a '
          'parameter or a slot';
    case 'silent':
      return detail == 'catch'
          ? 'rethrow, or report with FlutterError.reportError, so the failure '
              'is visible'
          : 'use of() so a missing ancestor fails with a clear message instead '
              'of falling back silently';
    case 'tokens':
      return 'take the value from the theme tokens instead of a literal';
    case 'allowlist':
      return 'every entry needs a reason that names the request or decision '
          'behind it, and a valid count';
    case 'growth':
      return 'stop and report this increase instead of working around it; an '
          'independent review decides whether it stays';
    case 'parse':
      return 'fix the syntax error';
  }
  return 'follow the repository rules';
}
