import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/menu_content_focus_entry.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/device.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class MenuDirectionalFocusBoundary extends StatefulWidget {
  const MenuDirectionalFocusBoundary({
    super.key,
    required this.navigationRail,
    required this.content,
    required this.navigationEntryFocusNode,
  });

  final Widget navigationRail;
  final Widget content;
  final FocusNode navigationEntryFocusNode;

  @override
  State<MenuDirectionalFocusBoundary> createState() =>
      _MenuDirectionalFocusBoundaryState();
}

class _MenuDirectionalFocusBoundaryState
    extends State<MenuDirectionalFocusBoundary> {
  final FocusScopeNode _navigationFocusScope = FocusScopeNode(
    debugLabel: 'menu navigation rail',
  );
  final FocusScopeNode _contentFocusScope = FocusScopeNode(
    debugLabel: 'menu content',
  );
  bool _contentFocusRequestPending = false;
  bool _contentFocusCheckScheduled = false;
  FocusNode? _pendingContentFocusOrigin;

  @override
  void dispose() {
    _navigationFocusScope.dispose();
    _contentFocusScope.dispose();
    super.dispose();
  }

  bool _requestContentFocus() {
    for (final entry in _contentFocusScope.descendants
        .whereType<MenuContentFocusEntryNode>()) {
      final entryContext = entry.context;
      if (entryContext == null || !TickerMode.valuesOf(entryContext).enabled) {
        continue;
      }
      final route = ModalRoute.of(entryContext);
      if (route != null && !route.isCurrent) {
        continue;
      }
      return entry.requestTargetFocus();
    }

    FocusNode? rememberedFocus = _contentFocusScope.focusedChild;
    while (rememberedFocus is FocusScopeNode) {
      rememberedFocus = rememberedFocus.focusedChild;
    }
    if (rememberedFocus != null &&
        rememberedFocus.canRequestFocus &&
        rememberedFocus.context != null &&
        rememberedFocus.ancestors.contains(_contentFocusScope)) {
      rememberedFocus.requestFocus();
      return true;
    }

    // A FocusScope can be traversable itself even when the routed page has no
    // actionable descendants yet. Do not park focus on that scope while an
    // asynchronously loaded page is still empty.
    final hasFocusableContent = _contentFocusScope.traversalDescendants.any(
      (node) => node is! FocusScopeNode,
    );
    return hasFocusableContent && _contentFocusScope.nextFocus();
  }

  bool _focusIsInNavigation(FocusNode? focus) {
    return focus == _navigationFocusScope ||
        (focus?.ancestors.contains(_navigationFocusScope) ?? false);
  }

  void _cancelPendingContentFocus() {
    _contentFocusRequestPending = false;
    _pendingContentFocusOrigin = null;
  }

  void _schedulePendingContentFocusCheck() {
    if (_contentFocusCheckScheduled) {
      return;
    }
    _contentFocusCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusCheckScheduled = false;
      if (!mounted || !_contentFocusRequestPending) {
        return;
      }

      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != _pendingContentFocusOrigin ||
          !_focusIsInNavigation(primaryFocus)) {
        _cancelPendingContentFocus();
        return;
      }
      if (_requestContentFocus()) {
        _cancelPendingContentFocus();
        return;
      }

      // Register one callback for the next real frame. This stays dormant
      // while the app is idle and runs when async route content is rebuilt.
      _schedulePendingContentFocusCheck();
    });
  }

  void _requestOrDeferContentFocus(FocusNode origin) {
    if (_requestContentFocus()) {
      _cancelPendingContentFocus();
      return;
    }
    _contentFocusRequestPending = true;
    _pendingContentFocusOrigin = origin;
    _schedulePendingContentFocusCheck();
  }

  Object? _handleDirectionalFocus(DirectionalFocusIntent intent) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusIsInNavigation = _focusIsInNavigation(primaryFocus);

    if (focusIsInNavigation &&
        intent.direction == TraversalDirection.right &&
        primaryFocus != null) {
      _requestOrDeferContentFocus(primaryFocus);
      return null;
    }

    _cancelPendingContentFocus();

    final moved = primaryFocus?.focusInDirection(intent.direction) ?? false;
    if (moved ||
        intent.direction != TraversalDirection.left ||
        focusIsInNavigation) {
      return null;
    }

    final rememberedFocus = _navigationFocusScope.focusedChild;
    if (rememberedFocus != null && rememberedFocus.canRequestFocus) {
      _navigationFocusScope.requestFocus();
    } else if (widget.navigationEntryFocusNode.canRequestFocus) {
      widget.navigationEntryFocusNode.requestFocus();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final child = FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Row(
        children: [
          FocusScope(
            node: _navigationFocusScope,
            child: widget.navigationRail,
          ),
          Expanded(
            child: FocusScope(
              node: _contentFocusScope,
              child: widget.content,
            ),
          ),
        ],
      ),
    );
    if (MediaQuery.navigationModeOf(context) != NavigationMode.directional) {
      return child;
    }
    return Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
          onInvoke: _handleDirectionalFocus,
        ),
      },
      child: child,
    );
  }
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  final _searchFocusNode = FocusNode(debugLabel: 'menu search');
  DateTime? _lastExitPromptAt;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  bool _isCovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      rootRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => _setCovered(true);

  @override
  void didPopNext() => _setCovered(false);

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    final currentIndex =
        menu.indexForPath(context.routeState(listen: false).uri.path);
    if (index == currentIndex) {
      return;
    }
    _outletKey.currentState?.navigate('/tab${menu.getPath(index)}/');
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    final currentIndex =
        menu.indexForPath(context.routeState(listen: false).uri.path);
    if (currentIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = menu.indexForPath(context.routeState().uri.path);
    return RouteVisibility(
      isCovered: _isCovered,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleSystemBack(context);
          }
        },
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.portrait
                ? _bottomMenu(context, selectedIndex)
                : _sideMenu(context, selectedIndex);
          },
        ),
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      // A non-poppable outlet must not override the shell's PopScope state.
      onNotification: (notification) => !notification.canHandlePop,
      child: RouterOutlet(key: _outletKey),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _bottomMenu(BuildContext context, int selectedIndex) {
    return Scaffold(
      body: _outlet(context),
      bottomNavigationBar: NavigationBar(
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: '推荐',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.timeline),
            icon: Icon(Icons.timeline_outlined),
            label: '时间表',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.favorite),
            icon: Icon(Icons.favorite_outlined),
            label: '追番',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }

  Widget _sideMenu(BuildContext context, int selectedIndex) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: MenuDirectionalFocusBoundary(
        navigationEntryFocusNode: _searchFocusNode,
        navigationRail: EmbeddedNativeControlArea(
          child: NavigationRail(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            groupAlignment: 1,
            leading: FloatingActionButton(
              elevation: 0,
              heroTag: null,
              focusNode: _searchFocusNode,
              autofocus: isAndroidTV(),
              tooltip: '搜索',
              onPressed: () => context.pushNamed('/search/'),
              child: const Icon(Icons.search),
            ),
            labelType: NavigationRailLabelType.selected,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                selectedIcon: Icon(Icons.home),
                icon: Icon(Icons.home_outlined),
                label: Text('推荐'),
              ),
              NavigationRailDestination(
                selectedIcon: Icon(Icons.timeline),
                icon: Icon(Icons.timeline_outlined),
                label: Text('时间表'),
              ),
              NavigationRailDestination(
                selectedIcon: Icon(Icons.favorite),
                icon: Icon(Icons.favorite_border),
                label: Text('追番'),
              ),
              NavigationRailDestination(
                selectedIcon: Icon(Icons.settings),
                icon: Icon(Icons.settings_outlined),
                label: Text('我的'),
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: _selectDestination,
          ),
        ),
        content: _outlet(context, borderRadius: borderRadius),
      ),
    );
  }
}
