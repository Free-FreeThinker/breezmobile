import 'dart:async';
import 'dart:io';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/backup/backup_bloc.dart';
import 'package:breez/bloc/connect_pay/connect_pay_bloc.dart';
import 'package:breez/bloc/invoice/invoice_bloc.dart';
import 'package:breez/bloc/lsp/lsp_bloc.dart';
import 'package:breez/bloc/user_profile/user_profile_bloc.dart';
import 'package:breez/routes/shared/account_required_actions.dart';
import 'package:breez/routes/shared/no_connection_dialog.dart';
import 'package:breez/routes/user/connect_to_pay/connect_to_pay_page.dart';
import 'package:breez/routes/user/ctp_join_session_handler.dart';
import 'package:breez/routes/user/received_invoice_notification.dart';
import 'package:breez/routes/user/showPinHandler.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/widgets/barcode_scanner_placeholder.dart';
import 'package:breez/widgets/error_dialog.dart';
import 'package:breez/widgets/fade_in_widget.dart';
import 'package:breez/widgets/flushbar.dart';
import 'package:breez/widgets/lost_card_dialog.dart' as lostCard;
import 'package:breez/widgets/navigation_drawer.dart';
import 'package:breez/widgets/route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lnurl_handler.dart';
import '../sync_ui_handler.dart';
import 'account_page.dart';

final GlobalKey firstPaymentItemKey = GlobalKey();
final ScrollController scrollController = ScrollController();
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class Home extends StatefulWidget {
  final AccountBloc accountBloc;
  final InvoiceBloc invoiceBloc;
  final UserProfileBloc userProfileBloc;
  final ConnectPayBloc ctpBloc;
  final BackupBloc backupBloc;
  final LSPBloc lspBloc;

  Home(this.accountBloc, this.invoiceBloc, this.userProfileBloc, this.ctpBloc,
      this.backupBloc, this.lspBloc);

  final List<DrawerItemConfig> _screens = List<DrawerItemConfig>.unmodifiable(
      [DrawerItemConfig("breezHome", "Breez", "")]);

  final List<DrawerItemConfig> _majorActionsFunds =
      List<DrawerItemConfig>.unmodifiable([
    DrawerItemConfig("/add_funds", "Add Funds", "src/icon/add_funds.png"),
    DrawerItemConfig(
        "/withdraw_funds", "Remove Funds", "src/icon/withdraw_funds.png"),
    DrawerItemConfig(
        "/get_refund", "Get Refund", "src/icon/withdraw_funds.png"),
  ]);

  final List<DrawerItemConfig> _majorActionsPay =
      List<DrawerItemConfig>.unmodifiable([
    DrawerItemConfig(
        "/connect_to_pay", "Connect to Pay", "src/icon/connect_to_pay.png")
  ]);

  final List<DrawerItemConfig> _minorActionsCard =
      List<DrawerItemConfig>.unmodifiable([
    DrawerItemConfig("/order_card", "Order", "src/icon/order_card.png"),
    DrawerItemConfig(
        "/activate_card", "Activate", "src/icon/activate_card.png"),
    DrawerItemConfig("/lost_card", "Lost or Stolen", "src/icon/lost_card.png"),
  ]);

  final List<DrawerItemConfig> _minorActionsAdvanced =
      List<DrawerItemConfig>.unmodifiable([
    DrawerItemConfig("/network", "Network", "src/icon/network.png"),
    DrawerItemConfig("/security", "Security & Backup", "src/icon/security.png"),
    DrawerItemConfig("/developers", "Developers", "src/icon/developers.png"),
  ]);

  final Map<String, Widget> _screenBuilders = {
    "breezHome": AccountPage(firstPaymentItemKey, scrollController)
  };

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<Home> {
  String _activeScreen = "breezHome";
  Set _hiddenRountes = Set<String>();
  StreamSubscription<String> _accountNotificationsSubscription;

  @override
  void initState() {
    super.initState();
    _registerNotificationHandlers();
    listenNoConnection(context, widget.accountBloc);
    _listenBackupConflicts();
    _listenWhiltelistPermissionsRequest();
    _listenLSPSelectionPrompt();
    _hiddenRountes.add("/get_refund");
    widget.accountBloc.accountStream.listen((acc) {
      setState(() {
        if (acc != null &&
            acc.swapFundsStatus.maturedRefundableAddresses.length > 0) {
          _hiddenRountes.remove("/get_refund");
        } else {
          _hiddenRountes.add("/get_refund");
        }
      });
    });

    widget.accountBloc.accountStream.listen((acc) {
      var activeAccountRoutes = [
        "/connect_to_pay",
        "/pay_invoice",
        "/create_invoice"
      ];
      Function addOrRemove =
          acc.connected ? _hiddenRountes.remove : _hiddenRountes.add;
      setState(() {
        activeAccountRoutes.forEach((r) => addOrRemove(r));
      });
    });
  }

  @override
  void dispose() {
    _accountNotificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: FadeInWidget(
        child: Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              brightness: theme.themeId == "BLUE"
                  ? Brightness.light
                  : Theme.of(context).appBarTheme.brightness,
              centerTitle: false,
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: AccountRequiredActionsIndicator(
                      widget.backupBloc,
                      widget.accountBloc,
                      widget.userProfileBloc,
                      widget.lspBloc),
                ),
              ],
              leading: IconButton(
                  icon: ImageIcon(
                    AssetImage("src/icon/hamburger.png"),
                    size: 24.0,
                    color: Theme.of(context).appBarTheme.actionsIconTheme.color,
                  ),
                  onPressed: () => _scaffoldKey.currentState.openDrawer()),
              title: Image.asset(
                "src/images/logo-color.png",
                height: 23.5,
                width: 62.7,
                color: Theme.of(context).appBarTheme.color,
                colorBlendMode: BlendMode.srcATop,
              ),
              iconTheme: IconThemeData(color: Color.fromARGB(255, 0, 133, 251)),
              backgroundColor: Theme.of(context).backgroundColor,
              elevation: 0.0,
            ),
            drawer: NavigationDrawer(
                true,
                [
                  DrawerItemConfigGroup(
                      _filterItems(widget._majorActionsFunds)),
                  DrawerItemConfigGroup(_filterItems(widget._majorActionsPay)),
                  _buildMinorActionsInvoice(context),
                  DrawerItemConfigGroup(_filterItems(widget._minorActionsCard),
                      groupTitle: "Card", groupAssetImage: "src/icon/card.png"),
                  DrawerItemConfigGroup(
                      _filterItems(widget._minorActionsAdvanced),
                      groupTitle: "Advanced",
                      groupAssetImage: "src/icon/advanced.png"),
                ],
                _onNavigationItemSelected),
            body: widget._screenBuilders[_activeScreen]),
      ),
    );
  }

  DrawerItemConfigGroup _buildMinorActionsInvoice(BuildContext context) {
    List<DrawerItemConfig> minorActionsInvoice =
        List<DrawerItemConfig>.unmodifiable([
      DrawerItemConfig("/pay_invoice", "Pay Invoice", "src/icon/qr_scan.png",
          onItemSelected: (String name) async {
        try {
          String decodedQr = await BarcodeScanner.scan();
          widget.invoiceBloc.decodeInvoiceSink.add(decodedQr);
        } on PlatformException catch (e) {
          if (e.code == BarcodeScanner.CameraAccessDenied) {
            Navigator.of(context).push(FadeInRoute(
                builder: (_) => BarcodeScannerPlaceholder(widget.invoiceBloc)));
          }
        }
      }),
      DrawerItemConfig(
          "/create_invoice", "Receive via Invoice", "src/icon/paste.png"),
    ]);
    return DrawerItemConfigGroup(_filterItems(minorActionsInvoice));
  }

  _onNavigationItemSelected(String itemName) {
    if (widget._screens.map((sc) => sc.name).contains(itemName)) {
      setState(() {
        _activeScreen = itemName;
      });
    } else {
      if (itemName == "/lost_card") {
        showDialog(
            useRootNavigator: false,
            context: context,
            builder: (_) => lostCard.LostCardDialog(
                  context: context,
                ));
      } else {
        Navigator.of(context).pushNamed(itemName).then((message) {
          if (message != null && message.runtimeType == String) {
            showFlushbar(context, message: message);
          }
        });
      }
    }
  }

  void _registerNotificationHandlers() {
    InvoiceNotificationsHandler(
        context,
        widget.accountBloc,
        widget.invoiceBloc.receivedInvoicesStream,
        firstPaymentItemKey,
        scrollController,
        _scaffoldKey);
    LNURLHandler(context);
    CTPJoinSessionHandler(widget.ctpBloc, this.context, (session) {
      Navigator.popUntil(context, (route) {
        return route.settings.name != "/connect_to_pay";
      });
      var ctpRoute = FadeInRoute(
          builder: (_) => ConnectToPayPage(session),
          settings: RouteSettings(name: "/connect_to_pay"));
      Navigator.of(context).push(ctpRoute);
    }, (e) {
      promptError(
          context,
          "Connect to Pay",
          Text(e.toString(),
              style: Theme.of(context).dialogTheme.contentTextStyle));
    });
    SyncUIHandler(widget.accountBloc, context);
    ShowPinHandler(widget.userProfileBloc, context);

    _accountNotificationsSubscription = widget
        .accountBloc.accountNotificationsStream
        .listen((data) => showFlushbar(context, message: data),
            onError: (e) => showFlushbar(context, message: e.toString()));
  }

  void _listenBackupConflicts() {
    widget.accountBloc.nodeConflictStream.listen((_) async {
      Navigator.popUntil(context, (route) {
        return route.settings.name == "/";
      });
      await promptError(
          context,
          "Configuration Error",
          Text(
              "Breez detected another device is running with the same configuration (probably due to restore). Breez cannot run the same configuration on more than one device. Please reinstall Breez if you wish to continue using Breez on this device.",
              style: Theme.of(context).dialogTheme.contentTextStyle),
          okText: "Exit Breez",
          okFunc: () => exit(0),
          disableBack: true);
    });
  }

  void _listenLSPSelectionPrompt() async {
    widget.lspBloc.lspPromptStream.first
        .then((_) => Navigator.of(context).pushNamed("/select_lsp"));
  }

  void _listenWhiltelistPermissionsRequest() {
    widget.accountBloc.optimizationWhitelistExplainStream.listen((_) async {
      await promptError(
          context,
          "Background Synchronization",
          Text(
              "In order to support instantaneous payments, Breez needs your permission in order to synchronize the information while the app is not active. Please approve the app in the next dialog.",
              style: Theme.of(context).dialogTheme.contentTextStyle),
          okFunc: () =>
              widget.accountBloc.optimizationWhitelistRequestSink.add(null));
    });
  }

  List<DrawerItemConfig> _filterItems(List<DrawerItemConfig> items) {
    return items.where((c) => !_hiddenRountes.contains(c.name)).toList();
  }

  DrawerItemConfig get activeScreen {
    return widget._screens.firstWhere((screen) => screen.name == _activeScreen);
  }
}
