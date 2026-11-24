// original cm window in Sciter version.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/audio_input.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/deskcel/dk.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/chat_model.dart';
import 'package:flutter_hbb/models/cm_file_model.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:get/get.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../common/widgets/chat_page.dart';
import '../../models/file_model.dart';
import '../../models/platform_model.dart';
import '../../models/server_model.dart';

/// Set only by this window's own close control, and only once the user has confirmed. Any other
/// way the window can go - a session logout closing every window, the window manager, a native
/// title-bar button this app does not draw - leaves it false, which is the honest answer:
/// nothing in that close says who asked for it. It lives at file scope because the control that
/// sets it (`ConnectionManagerState`) and the handler that reads it (`_DesktopServerPageState`)
/// are different widgets.
bool _cmClosedByOperator = false;

class DesktopServerPage extends StatefulWidget {
  const DesktopServerPage({Key? key}) : super(key: key);

  @override
  State<DesktopServerPage> createState() => _DesktopServerPageState();
}

class _DesktopServerPageState extends State<DesktopServerPage>
    with WindowListener, AutomaticKeepAliveClientMixin {
  final tabController = gFFI.serverModel.tabController;

  _DesktopServerPageState() {
    gFFI.ffiModel.updateEventListener(gFFI.sessionId, "");
    Get.put<DesktopTabController>(tabController);
    tabController.onRemoved = (_, id) {
      onRemoveId(id);
    };
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    // Other platforms keep the old behaviour exactly: the ambiguity this guards against is a
    // Linux session logout, which closes every window in the session.
    final byOperator = _cmClosedByOperator || !isLinux;
    Future.wait([gFFI.serverModel.closeAll(byOperator: byOperator), gFFI.close()]).then((_) {
      if (isMacOS) {
        RdPlatformChannel.instance.terminate();
      } else {
        windowManager.setPreventClose(false);
        windowManager.close();
      }
    });
    super.onWindowClose();
  }

  void onRemoveId(String id) {
    if (tabController.state.value.tabs.isEmpty) {
      windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gFFI.serverModel),
        ChangeNotifierProvider.value(value: gFFI.chatModel),
      ],
      child: Consumer<ServerModel>(
        builder: (context, serverModel, child) {
          final body = Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: ConnectionManager(),
          );
          return isLinux
              ? buildVirtualWindowFrame(context, body)
              : workaroundWindowBorder(
                  context,
                  Container(
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: MyTheme.color(context).border!)),
                    child: body,
                  ));
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ConnectionManager extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ConnectionManagerState();
}

class ConnectionManagerState extends State<ConnectionManager>
    with WidgetsBindingObserver {
  final RxBool _controlPageBlock = false.obs;
  final RxBool _sidePageBlock = false.obs;

  ConnectionManagerState() {
    gFFI.serverModel.tabController.onSelected = (client_id_str) {
      final client_id = int.tryParse(client_id_str);
      if (client_id != null) {
        final client =
            gFFI.serverModel.clients.firstWhereOrNull((e) => e.id == client_id);
        if (client != null) {
          gFFI.chatModel.changeCurrentKey(MessageKey(client.peerId, client.id));
          if (client.unreadChatMessageCount.value > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              client.unreadChatMessageCount.value = 0;
              gFFI.chatModel.showChatPage(MessageKey(client.peerId, client.id));
            });
          }
          windowManager.setTitle(getWindowNameWithId(client.peerId));
          gFFI.cmFileModel.updateCurrentClientId(client.id);
        }
      }
    };
    gFFI.chatModel.isConnManager = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!allowRemoteCMModification()) {
        shouldBeBlocked(_controlPageBlock, null);
        shouldBeBlocked(_sidePageBlock, null);
      }
    }
  }

  @override
  void initState() {
    gFFI.serverModel.updateClientState();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverModel = Provider.of<ServerModel>(context);
    pointerHandler(PointerEvent e) {
      if (serverModel.cmHiddenTimer != null) {
        serverModel.cmHiddenTimer!.cancel();
        serverModel.cmHiddenTimer = null;
        debugPrint("CM hidden timer has been canceled");
      }
    }

    return serverModel.clients.isEmpty
        ? Column(
            children: [
              buildTitleBar(),
              Expanded(
                child: Center(
                  child: Text(translate("Waiting")),
                ),
              ),
            ],
          )
        : Listener(
            onPointerDown: pointerHandler,
            onPointerMove: pointerHandler,
            child: DesktopTab(
              showTitle: false,
              showMaximize: false,
              showMinimize: true,
              showClose: true,
              onWindowCloseButton: handleWindowCloseButton,
              controller: serverModel.tabController,
              selectedBorderColor: MyTheme.accent,
              maxLabelWidth: 100,
              tail: null, //buildScrollJumper(),
              tabBuilder: (key, icon, label, themeConf) {
                final client = serverModel.clients
                    .firstWhereOrNull((client) => client.id.toString() == key);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Tooltip(
                        message: key,
                        waitDuration: Duration(seconds: 1),
                        child: label),
                    unreadMessageCountBuilder(client?.unreadChatMessageCount)
                        .marginOnly(left: 4),
                  ],
                );
              },
              pageViewBuilder: (pageView) => LayoutBuilder(
                builder: (context, constrains) {
                  var borderWidth = 0.0;
                  if (constrains.maxWidth >
                      kConnectionManagerWindowSizeClosedChat.width) {
                    borderWidth = kConnectionManagerWindowSizeOpenChat.width -
                        constrains.maxWidth;
                  } else {
                    borderWidth = kConnectionManagerWindowSizeClosedChat.width -
                        constrains.maxWidth;
                  }
                  if (borderWidth < 0 || borderWidth > 50) {
                    borderWidth = 0;
                  }
                  final realClosedWidth =
                      kConnectionManagerWindowSizeClosedChat.width -
                          borderWidth;
                  final realChatPageWidth =
                      constrains.maxWidth - realClosedWidth;
                  final row = Row(children: [
                    if (constrains.maxWidth >
                        kConnectionManagerWindowSizeClosedChat.width)
                      Consumer<ChatModel>(
                          builder: (_, model, child) => SizedBox(
                                width: realChatPageWidth,
                                child: allowRemoteCMModification()
                                    ? buildSidePage()
                                    : buildRemoteBlock(
                                        child: buildSidePage(),
                                        block: _sidePageBlock,
                                        mask: true),
                              )),
                    SizedBox(
                        width: realClosedWidth,
                        child: SizedBox(
                            width: realClosedWidth,
                            child: allowRemoteCMModification()
                                ? pageView
                                : buildRemoteBlock(
                                    child: _buildKeyEventBlock(pageView),
                                    block: _controlPageBlock,
                                    mask: false,
                                  ))),
                  ]);
                  return Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: row,
                  );
                },
              ),
            ),
          );
  }

  Widget buildSidePage() {
    final selected = gFFI.serverModel.tabController.state.value.selected;
    if (selected < 0 || selected >= gFFI.serverModel.clients.length) {
      return Offstage();
    }
    final clientType = gFFI.serverModel.clients[selected].type_();
    if (clientType == ClientType.file) {
      return _FileTransferLogPage();
    } else {
      return ChatPage(type: ChatPageType.desktopCM);
    }
  }

  Widget _buildKeyEventBlock(Widget child) {
    return ExcludeFocus(child: child, excluding: true);
  }

  Widget buildTitleBar() {
    return SizedBox(
      height: kDesktopRemoteTabBarHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _AppIcon(),
          Expanded(
            child: GestureDetector(
              onPanStart: (d) {
                windowManager.startDragging();
              },
              child: Container(
                color: Theme.of(context).colorScheme.background,
              ),
            ),
          ),
          const SizedBox(
            width: 4.0,
          ),
          const _CloseButton()
        ],
      ),
    );
  }

  Widget buildScrollJumper() {
    final offstage = gFFI.serverModel.clients.length < 2;
    final sc = gFFI.serverModel.tabController.state.value.scrollController;
    return Offstage(
        offstage: offstage,
        child: Row(
          children: [
            ActionIcon(
                icon: Icons.arrow_left, iconSize: 22, onTap: sc.backward),
            ActionIcon(
                icon: Icons.arrow_right, iconSize: 22, onTap: sc.forward),
          ],
        ));
  }

  Future<bool> handleWindowCloseButton() async {
    var tabController = gFFI.serverModel.tabController;
    final connLength = tabController.length;
    if (connLength <= 1) {
      _cmClosedByOperator = true;
      windowManager.close();
      return true;
    } else {
      final bool res;
      if (!option2bool(kOptionEnableConfirmClosingTabs,
          bind.mainGetLocalOption(key: kOptionEnableConfirmClosingTabs))) {
        res = true;
      } else {
        res = await closeConfirmDialog();
      }
      if (res) {
        // After the dialog, never before it: an external close while it is open must not
        // inherit an intent the user had not expressed yet.
        _cmClosedByOperator = true;
        windowManager.close();
      }
      return res;
    }
  }
}

Widget buildConnectionCard(Client client) {
  if (isDesktop) {
    // Deskcel: telas 2a (pedido) e 2b (aceito) do modelo.
    return Consumer<ServerModel>(
        builder: (context, value, child) =>
            _DkCmCard(key: ValueKey(client.id), client: client));
  }
  return Consumer<ServerModel>(
    builder: (context, value, child) => Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      key: ValueKey(client.id),
      children: [
        _CmHeader(client: client),
        client.type_() == ClientType.file ||
                client.type_() == ClientType.portForward ||
                client.type_() == ClientType.terminal ||
                client.disconnected
            ? Offstage()
            : _PrivilegeBoard(client: client),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _CmControlPanel(client: client),
          ),
        )
      ],
    ).paddingSymmetric(vertical: 4.0, horizontal: 8.0),
  );
}

/// Deskcel: janela do cliente (320 × 520) no desenho do modelo, com todas as funções da original.
class _DkCmCard extends StatefulWidget {
  final Client client;
  const _DkCmCard({Key? key, required this.client}) : super(key: key);

  @override
  State<_DkCmCard> createState() => _DkCmCardState();
}

class _DkCmCardState extends State<_DkCmCard>
    with AutomaticKeepAliveClientMixin {
  Client get client => widget.client;
  final _time = 0.obs;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (client.authorized && !client.disconnected) {
        _time.value = _time.value + 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gFFI.serverModel.tabController.onSelected?.call(client.id.toString());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _click(VoidCallback f) => checkClickTime(client.id, f);

  String get _tipo {
    switch (client.type_()) {
      case ClientType.file:
        return translate('Transfer file');
      case ClientType.camera:
        return translate('View camera');
      case ClientType.terminal:
        return translate('Terminal');
      default:
        return client.portForward.isNotEmpty
            ? 'Port Forward: ${client.portForward}'
            : '';
    }
  }

  Widget _avatar() {
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(color: Dk.branco, shape: BoxShape.circle),
      foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: Dk.linha)),
      alignment: Alignment.center,
      child: const DkIcon('pessoa', size: 32, color: Dk.terracota),
    );
    return buildAvatarWidget(
            avatar: client.avatar,
            size: 64,
            borderRadius: 32,
            fallback: fallback) ??
        fallback;
  }

  Widget _centro(double top, Widget child) =>
      Positioned(left: 24, top: top, width: 272, child: Center(child: child));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final model = Provider.of<ServerModel>(context);
    final children = client.authorized
        ? (client.disconnected
            ? _buildDesconectado(context)
            : _buildAceito(context, model))
        : _buildPedido(context, model);
    return Container(
        color: Dk.off, child: SizedBox.expand(child: Stack(children: children)));
  }

  List<Widget> _buildPedido(BuildContext context, ServerModel model) {
    final canElevate = bind.cmCanElevate();
    final showElevation = canElevate &&
        model.showElevation &&
        client.type_() == ClientType.remote &&
        bind.mainGetBuildinOption(
                key: kOptionHideElevateButtonInAcceptWindow) !=
            'Y';
    final showAccept = model.approveMode != 'password';
    final explicacao = client.type_() == ClientType.file
        ? 'Ele vai poder enviar e receber arquivos deste computador.'
        : 'Ele vai ver a sua tela e poderá usar o mouse e o teclado deste computador.';
    return [
      _centro(
          24,
          Text('PEDIDO DE ACESSO',
              style: Dk.et.copyWith(color: Dk.terracota))),
      Positioned(left: 128, top: 56, child: _avatar()),
      _centro(
          136,
          Text(client.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Dk.t(18, FontWeight.w600, 24, ls: -.03))),
      _centro(
          160,
          Text(
              _tipo.isEmpty
                  ? 'Técnico da Hostcel'
                  : 'Técnico da Hostcel · $_tipo',
              style: Dk.desc)),
      Positioned(
        left: 24,
        top: 192,
        child: DkCard(
          width: 272,
          height: 64,
          child: Stack(children: [
            Positioned(
                left: 24, top: 12, child: Text('ID DO TÉCNICO', style: Dk.et)),
            Positioned(
                left: 24,
                top: 28,
                child: Text(formatID(client.peerId),
                    style: Dk.t(18, FontWeight.w500, 24, family: Dk.mono))),
          ]),
        ),
      ),
      Positioned(
          left: 24,
          top: 272,
          width: 272,
          child: Text(explicacao,
              textAlign: TextAlign.center,
              style: Dk.desc.copyWith(color: Dk.tinta))),
      if (showElevation && showAccept)
        Positioned(
            left: 24,
            top: 312,
            child: Tooltip(
              message: translate('accept_and_elevate_btn_tooltip'),
              child: DkSecondaryButton(translate('Accept and Elevate'),
                  icon: 'escudo',
                  width: 272,
                  height: 40,
                  onTap: () => _click(() {
                        model.sendLoginResponse(client, true);
                        model.setShowElevation(false);
                        bind.cmElevatePortable(connId: client.id);
                        windowManager.minimize();
                      })),
            )),
      if (showAccept)
        Positioned(
            left: 24,
            top: 360,
            child: DkPrimaryButton('Aceitar',
                icon: 'check',
                width: 272,
                onTap: () => _click(() {
                      model.sendLoginResponse(client, true);
                      windowManager.minimize();
                    }))),
      Positioned(
          left: 24,
          top: 416,
          child: DkSecondaryButton('Recusar',
              icon: 'x',
              iconColor: Dk.tinta,
              width: 272,
              height: 48,
              style: Dk.t(15, FontWeight.w500, 20),
              onTap: () =>
                  _click(() => bind.cmCloseConnection(connId: client.id)))),
    ];
  }

  Widget _linha(
      {required String icon,
      required String nome,
      required bool valor,
      required String perm,
      required bool canModify,
      required void Function(bool) set}) {
    return SizedBox(
      height: 48,
      child: Stack(children: [
        Positioned(
            left: 20,
            top: 14,
            child: DkIcon(icon, color: valor ? Dk.terracota : Dk.apoio)),
        Positioned(
            left: 52,
            top: 14,
            right: 72,
            child: Text(nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Dk.t(14, FontWeight.w400, 20,
                    color: valor ? Dk.tinta : Dk.apoio))),
        Positioned(
          left: 212,
          top: 12,
          child: DkSwitch(
            value: valor,
            onChanged: canModify
                ? (v) => _click(() {
                      bind.cmSwitchPermission(
                          connId: client.id, name: perm, enabled: v);
                      setState(() => set(v));
                    })
                : null,
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildAceito(BuildContext context, ServerModel model) {
    final canModify =
        bind.mainGetBuildinOption(key: kOptionEnablePermChangeInAcceptWindow) !=
            'N';
    final showPerms = !(client.type_() == ClientType.file ||
        client.type_() == ClientType.portForward ||
        client.type_() == ClientType.terminal);
    final linhas = <Widget>[];
    void add(String icon, String nome, bool valor, String perm,
        void Function(bool) set) {
      if (linhas.isNotEmpty) {
        linhas.add(const Divider(height: 1, thickness: 1, color: Dk.linha));
      }
      linhas.add(_linha(
          icon: icon,
          nome: nome,
          valor: valor,
          perm: perm,
          canModify: canModify,
          set: set));
    }

    if (client.type_() == ClientType.camera) {
      add('audio', 'Áudio', client.audio, 'audio', (v) => client.audio = v);
      add('monitor', translate('Enable recording session'), client.recording,
          'recording', (v) => client.recording = v);
    } else {
      add('teclado', 'Teclado e mouse', client.keyboard, 'keyboard',
          (v) => client.keyboard = v);
      add('prancheta', 'Área de transferência', client.clipboard, 'clipboard',
          (v) => client.clipboard = v);
      add('arquivo', 'Arquivos', client.file, 'file', (v) => client.file = v);
      add('audio', 'Áudio', client.audio, 'audio', (v) => client.audio = v);
      add('nova', translate('Enable remote restart'), client.restart,
          'restart', (v) => client.restart = v);
      add('monitor', translate('Enable recording session'), client.recording,
          'recording', (v) => client.recording = v);
      if (isWindows) {
        add('cadeado', translate('Enable blocking user input'),
            client.blockInput, 'block_input', (v) => client.blockInput = v);
      }
      if (bind.mainSupportedPrivacyModeImpls() != '[]') {
        add('escudo', translate('Enable privacy mode'), client.privacyMode,
            'privacy_mode', (v) => client.privacyMode = v);
      }
    }

    final showElevation = bind.cmCanElevate() &&
        model.showElevation &&
        client.type_() == ClientType.remote;
    final extras = <Widget>[
      if (client.incomingVoiceCall) ...[
        DkSecondaryButton(translate('Accept'),
            icon: 'audio',
            width: 132,
            height: 40,
            onTap: () => _click(() => bind.cmHandleIncomingVoiceCall(
                id: client.id, accept: true))),
        DkSecondaryButton(translate('Dismiss'),
            icon: 'x',
            width: 132,
            height: 40,
            onTap: () => _click(() => bind.cmHandleIncomingVoiceCall(
                id: client.id, accept: false))),
      ],
      if (client.inVoiceCall)
        DkSecondaryButton(translate('Stop voice call'),
            icon: 'x',
            width: 272,
            height: 40,
            onTap: () => _click(() => bind.cmCloseVoiceCall(id: client.id))),
      if (client.fromSwitch)
        DkSecondaryButton(translate('Switch Sides'),
            icon: 'voltar',
            width: 272,
            height: 40,
            onTap: () => _click(() => bind.cmSwitchBack(connId: client.id))),
      if (showElevation)
        DkSecondaryButton(translate('Elevate'),
            icon: 'escudo',
            width: 272,
            height: 40,
            onTap: () => _click(() {
                  model.setShowElevation(false);
                  bind.cmElevatePortable(connId: client.id);
                  windowManager.minimize();
                })),
    ];
    final podeChat = client.type_() == ClientType.remote ||
        client.type_() == ClientType.file ||
        client.type_() == ClientType.camera;
    final isFile = client.type_() == ClientType.file;

    return [
      _centro(
          24,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    const BoxDecoration(color: Dk.ok, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('CONECTADO HÁ', style: Dk.et),
          ])),
      _centro(
          40,
          Obx(() => Text(formatDurationToTime(Duration(seconds: _time.value)),
              style: Dk.t(32, FontWeight.w600, 40, ls: -.03).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])))),
      _centro(
          88,
          Text.rich(
            TextSpan(style: Dk.desc, children: [
              TextSpan(
                  text:
                      '${client.name}${_tipo.isEmpty ? '' : ' · $_tipo'} · ID '),
              TextSpan(
                  text: formatID(client.peerId),
                  style: Dk.t(12, FontWeight.w500, 20,
                      color: Dk.apoio, family: Dk.mono)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
      if (podeChat)
        Positioned(
          right: 16,
          top: 16,
          child: DkIconButton(isFile ? 'arquivo' : 'mais',
              size: 32,
              background: Dk.branco,
              border: true,
              tooltip: isFile ? translate('Transfer file') : translate('Chat'),
              onTap: () => _click(() {
                    if (isFile) {
                      gFFI.chatModel.toggleCMFilePage();
                    } else {
                      gFFI.chatModel.toggleCMChatPage(
                          MessageKey(client.peerId, client.id));
                    }
                  })),
        ),
      if (showPerms) ...[
        Positioned(
            left: 24, top: 128, child: Text('PERMISSÕES', style: Dk.et)),
        Positioned(
          left: 24,
          top: 152,
          child: DkCard(
            width: 272,
            height: 192,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dk.rCartao),
              child: SingleChildScrollView(child: Column(children: linhas)),
            ),
          ),
        ),
      ],
      if (extras.isEmpty)
        Positioned(
            left: 24,
            top: 360,
            width: 272,
            child: Text('Desligue qualquer permissão a qualquer momento.',
                style: Dk.peq))
      else
        Positioned(
            left: 24,
            top: 352,
            width: 272,
            child: Wrap(spacing: 8, runSpacing: 8, children: extras)),
      Positioned(
          left: 24,
          top: 416,
          child: DkPrimaryButton('Encerrar acesso',
              icon: 'encerrar',
              width: 272,
              onTap: () =>
                  _click(() => bind.cmCloseConnection(connId: client.id)))),
    ];
  }

  List<Widget> _buildDesconectado(BuildContext context) {
    return [
      _centro(24, Text(translate('Disconnected').toUpperCase(), style: Dk.et)),
      Positioned(left: 128, top: 56, child: _avatar()),
      _centro(
          136,
          Text(client.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Dk.t(18, FontWeight.w600, 24, ls: -.03))),
      _centro(
          160,
          Obx(() => Text(formatDurationToTime(Duration(seconds: _time.value)),
              style: Dk.desc))),
      Positioned(
          left: 24,
          top: 416,
          child: DkPrimaryButton(translate('Close'),
              width: 272,
              onTap: () => _click(() async {
                    await bind.cmRemoveDisconnectedConnection(
                        connId: client.id);
                    if (await bind.cmGetClientsLength() == 0) {
                      windowManager.close();
                    }
                  }))),
    ];
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.0),
      child: loadIcon(30),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        windowManager.close();
      },
      icon: const Icon(
        IconFont.close,
        size: 18,
      ),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }
}

class _CmHeader extends StatefulWidget {
  final Client client;

  const _CmHeader({Key? key, required this.client}) : super(key: key);

  @override
  State<_CmHeader> createState() => _CmHeaderState();
}

class _CmHeaderState extends State<_CmHeader>
    with AutomaticKeepAliveClientMixin {
  Client get client => widget.client;

  final _time = 0.obs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (client.authorized && !client.disconnected) {
        _time.value = _time.value + 1;
      }
    });
    // Call onSelected in post frame callback, since we cannot guarantee that the callback will not call setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gFFI.serverModel.tabController.onSelected?.call(client.id.toString());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xffec7a2c),
            Color(0xffa8461c),
          ],
        ),
      ),
      margin: EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
      padding: EdgeInsets.only(
        top: 10.0,
        bottom: 10.0,
        left: 10.0,
        right: 5.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientAvatar().marginOnly(right: 10.0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                    child: Text(
                  client.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                )),
                FittedBox(
                  child: Text(
                    "(${client.peerId})",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                if (client.type_() == ClientType.terminal)
                  FittedBox(
                    child: Text(
                      translate("Terminal"),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                if (client.type_() == ClientType.file)
                  FittedBox(
                    child: Text(
                      translate("Transfer file"),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                if (client.type_() == ClientType.camera)
                  FittedBox(
                    child: Text(
                      translate("View camera"),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                if (client.portForward.isNotEmpty)
                  FittedBox(
                    child: Text(
                      "Port Forward: ${client.portForward}",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                SizedBox(height: 10.0),
                FittedBox(
                    child: Row(
                  children: [
                    Text(
                      client.authorized
                          ? client.disconnected
                              ? translate("Disconnected")
                              : translate("Connected")
                          : "${translate("Request access to your device")}...",
                      style: TextStyle(color: Colors.white),
                    ).marginOnly(right: 8.0),
                    if (client.authorized)
                      Obx(
                        () => Text(
                          formatDurationToTime(
                            Duration(seconds: _time.value),
                          ),
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                  ],
                ))
              ],
            ),
          ),
          Offstage(
            offstage: !client.authorized ||
                (client.type_() != ClientType.remote &&
                    client.type_() != ClientType.file &&
                    client.type_() != ClientType.camera),
            child: IconButton(
              onPressed: () => checkClickTime(client.id, () {
                if (client.type_() == ClientType.file) {
                  gFFI.chatModel.toggleCMFilePage();
                } else {
                  gFFI.chatModel
                      .toggleCMChatPage(MessageKey(client.peerId, client.id));
                }
              }),
              icon: SvgPicture.asset(client.type_() == ClientType.file
                  ? 'assets/file_transfer.svg'
                  : 'assets/chat2.svg'),
              splashRadius: kDesktopIconButtonSplashRadius,
            ),
          )
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildClientAvatar() {
    return buildAvatarWidget(
          avatar: client.avatar,
          size: 70,
          borderRadius: 15,
          fallback: _buildInitialAvatar(),
        ) ??
        _buildInitialAvatar();
  }

  Widget _buildInitialAvatar() {
    return Container(
      width: 70,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: str2color(client.name),
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Text(
        client.name.isNotEmpty ? client.name[0] : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 55,
        ),
      ),
    );
  }
}

class _PrivilegeBoard extends StatefulWidget {
  final Client client;

  const _PrivilegeBoard({Key? key, required this.client}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PrivilegeBoardState();
}

class _PrivilegeBoardState extends State<_PrivilegeBoard> {
  late final client = widget.client;
  Widget buildPermissionIcon(bool enabled, IconData iconData,
      Function(bool)? onTap, String tooltipText,
      {required bool canModify}) {
    return Tooltip(
      message: "$tooltipText: ${enabled ? "ON" : "OFF"}",
      waitDuration: Duration.zero,
      child: Container(
        decoration: BoxDecoration(
          color: enabled
              ? (canModify ? MyTheme.accent : MyTheme.accent.withOpacity(0.6))
              : Colors.grey[700],
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: EdgeInsets.all(8.0),
        child: InkWell(
          onTap: canModify
              ? () =>
                  checkClickTime(widget.client.id, () => onTap?.call(!enabled))
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Icon(
                  iconData,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = 4;
    final spacing = 10.0;
    final canModifyPermission =
        bind.mainGetBuildinOption(key: kOptionEnablePermChangeInAcceptWindow) !=
            'N';
    return Container(
      width: double.infinity,
      height: 160.0,
      margin: EdgeInsets.all(5.0),
      padding: EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: Theme.of(context).colorScheme.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            translate("Permissions"),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ).marginOnly(left: 4.0, bottom: 8.0),
          Expanded(
            child: GridView.count(
              crossAxisCount: crossAxisCount,
              padding: EdgeInsets.symmetric(horizontal: spacing),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: client.type_() == ClientType.camera
                  ? [
                      buildPermissionIcon(
                        client.audio,
                        Icons.volume_up_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "audio",
                              enabled: enabled);
                          setState(() {
                            client.audio = enabled;
                          });
                        },
                        translate('Enable audio'),
                        canModify: canModifyPermission,
                      ),
                      buildPermissionIcon(
                        client.recording,
                        Icons.videocam_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "recording",
                              enabled: enabled);
                          setState(() {
                            client.recording = enabled;
                          });
                        },
                        translate('Enable recording session'),
                        canModify: canModifyPermission,
                      ),
                    ]
                  : [
                      buildPermissionIcon(
                        client.keyboard,
                        Icons.keyboard,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "keyboard",
                              enabled: enabled);
                          setState(() {
                            client.keyboard = enabled;
                          });
                        },
                        translate('Enable keyboard/mouse'),
                        canModify: canModifyPermission,
                      ),
                      buildPermissionIcon(
                        client.clipboard,
                        Icons.assignment_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "clipboard",
                              enabled: enabled);
                          setState(() {
                            client.clipboard = enabled;
                          });
                        },
                        translate('Enable clipboard'),
                        canModify: canModifyPermission,
                      ),
                      buildPermissionIcon(
                        client.audio,
                        Icons.volume_up_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "audio",
                              enabled: enabled);
                          setState(() {
                            client.audio = enabled;
                          });
                        },
                        translate('Enable audio'),
                        canModify: canModifyPermission,
                      ),
                      buildPermissionIcon(
                        client.file,
                        Icons.upload_file_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "file",
                              enabled: enabled);
                          setState(() {
                            client.file = enabled;
                          });
                        },
                        translate('Enable file copy and paste'),
                        canModify: canModifyPermission,
                      ),
                      buildPermissionIcon(
                        client.restart,
                        Icons.restart_alt_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "restart",
                              enabled: enabled);
                          setState(() {
                            client.restart = enabled;
                          });
                        },
                        translate('Enable remote restart'),
                        canModify: canModifyPermission,
                      ),
                      buildPermissionIcon(
                        client.recording,
                        Icons.videocam_rounded,
                        (enabled) {
                          bind.cmSwitchPermission(
                              connId: client.id,
                              name: "recording",
                              enabled: enabled);
                          setState(() {
                            client.recording = enabled;
                          });
                        },
                        translate('Enable recording session'),
                        canModify: canModifyPermission,
                      ),
                      // only windows support block input
                      if (isWindows)
                        buildPermissionIcon(
                          client.blockInput,
                          Icons.block,
                          (enabled) {
                            bind.cmSwitchPermission(
                                connId: client.id,
                                name: "block_input",
                                enabled: enabled);
                            setState(() {
                              client.blockInput = enabled;
                            });
                          },
                          translate('Enable blocking user input'),
                          canModify: canModifyPermission,
                        ),
                      if (bind.mainSupportedPrivacyModeImpls() != '[]')
                        buildPermissionIcon(
                          client.privacyMode,
                          Icons.visibility_off,
                          (enabled) {
                            bind.cmSwitchPermission(
                                connId: client.id,
                                name: "privacy_mode",
                                enabled: enabled);
                            setState(() {
                              client.privacyMode = enabled;
                            });
                          },
                          translate('Enable privacy mode'),
                          canModify: canModifyPermission,
                        )
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

const double buttonBottomMargin = 8;

class _CmControlPanel extends StatelessWidget {
  final Client client;

  const _CmControlPanel({Key? key, required this.client}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return client.authorized
        ? client.disconnected
            ? buildDisconnected(context)
            : buildAuthorized(context)
        : buildUnAuthorized(context);
  }

  buildAuthorized(BuildContext context) {
    final bool canElevate = bind.cmCanElevate();
    final model = Provider.of<ServerModel>(context);
    final showElevation = canElevate &&
        model.showElevation &&
        client.type_() == ClientType.remote;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Offstage(
          offstage: !client.inVoiceCall,
          child: Row(
            children: [
              Expanded(
                child: buildButton(context,
                    color: MyTheme.accent,
                    onClick: null, onTapDown: (details) async {
                  final devicesInfo =
                      await AudioInput.getDevicesInfo(true, true);
                  List<String> devices = devicesInfo['devices'] as List<String>;
                  if (devices.isEmpty) {
                    msgBox(
                      gFFI.sessionId,
                      'custom-nocancel-info',
                      'Prompt',
                      'no_audio_input_device_tip',
                      '',
                      gFFI.dialogManager,
                    );
                    return;
                  }

                  String currentDevice = devicesInfo['current'] as String;
                  final x = details.globalPosition.dx;
                  final y = details.globalPosition.dy;
                  final position = RelativeRect.fromLTRB(x, y, x, y);
                  showMenu(
                    context: context,
                    position: position,
                    items: devices
                        .map((d) => PopupMenuItem<String>(
                              value: d,
                              height: 18,
                              padding: EdgeInsets.zero,
                              onTap: () => AudioInput.setDevice(d, true, true),
                              child: IgnorePointer(
                                  child: RadioMenuButton(
                                value: d,
                                groupValue: currentDevice,
                                onChanged: (v) {
                                  if (v != null)
                                    AudioInput.setDevice(v, true, true);
                                },
                                child: Container(
                                  child: Text(
                                    d,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          kConnectionManagerWindowSizeClosedChat
                                                  .width -
                                              80),
                                ),
                              )),
                            ))
                        .toList(),
                  );
                },
                    icon: Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    text: "Audio input",
                    textColor: Colors.white),
              ),
              Expanded(
                child: buildButton(
                  context,
                  color: Colors.red,
                  onClick: () => closeVoiceCall(),
                  icon: Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  text: "Stop voice call",
                  textColor: Colors.white,
                ),
              )
            ],
          ),
        ),
        Offstage(
          offstage: !client.incomingVoiceCall,
          child: Row(
            children: [
              Expanded(
                child: buildButton(context,
                    color: MyTheme.accent,
                    onClick: () => handleVoiceCall(true),
                    icon: Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    text: "Accept",
                    textColor: Colors.white),
              ),
              Expanded(
                child: buildButton(
                  context,
                  color: Colors.red,
                  onClick: () => handleVoiceCall(false),
                  icon: Icon(
                    Icons.phone_disabled_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  text: "Dismiss",
                  textColor: Colors.white,
                ),
              )
            ],
          ),
        ),
        Offstage(
          offstage: !client.fromSwitch,
          child: buildButton(context,
              color: Colors.purple,
              onClick: () => handleSwitchBack(context),
              icon: Icon(Icons.reply, color: Colors.white),
              text: "Switch Sides",
              textColor: Colors.white),
        ),
        Offstage(
          offstage: !showElevation,
          child: buildButton(
            context,
            color: MyTheme.accent,
            onClick: () {
              handleElevate(context);
              windowManager.minimize();
            },
            icon: Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 14,
            ),
            text: 'Elevate',
            textColor: Colors.white,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: buildButton(context,
                  color: Colors.redAccent,
                  onClick: handleDisconnect,
                  text: 'Disconnect',
                  icon: Icon(
                    Icons.link_off_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  textColor: Colors.white),
            ),
          ],
        )
      ],
    ).marginOnly(bottom: buttonBottomMargin);
  }

  buildDisconnected(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
            child: buildButton(context,
                color: MyTheme.accent,
                onClick: handleClose,
                text: 'Close',
                textColor: Colors.white)),
      ],
    ).marginOnly(bottom: buttonBottomMargin);
  }

  buildUnAuthorized(BuildContext context) {
    final bool canElevate = bind.cmCanElevate();
    final model = Provider.of<ServerModel>(context);
    final showElevation = canElevate &&
        model.showElevation &&
        client.type_() == ClientType.remote &&
        bind.mainGetBuildinOption(
                key: kOptionHideElevateButtonInAcceptWindow) !=
            'Y';
    final showAccept = model.approveMode != 'password';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Offstage(
          offstage: !showElevation || !showAccept,
          child: buildButton(context, color: Colors.green[700], onClick: () {
            handleAccept(context);
            handleElevate(context);
            windowManager.minimize();
          },
              text: 'Accept and Elevate',
              icon: Icon(
                Icons.security_rounded,
                color: Colors.white,
                size: 14,
              ),
              textColor: Colors.white,
              tooltip: 'accept_and_elevate_btn_tooltip'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showAccept)
              Expanded(
                child: Column(
                  children: [
                    buildButton(
                      context,
                      color: MyTheme.accent,
                      onClick: () {
                        handleAccept(context);
                        windowManager.minimize();
                      },
                      text: 'Accept',
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: buildButton(
                context,
                color: Colors.transparent,
                border: Border.all(color: Colors.grey),
                onClick: handleDisconnect,
                text: 'Cancel',
                textColor: null,
              ),
            ),
          ],
        ),
      ],
    ).marginOnly(bottom: buttonBottomMargin);
  }

  Widget buildButton(BuildContext context,
      {required Color? color,
      GestureTapCallback? onClick,
      Widget? icon,
      BoxBorder? border,
      required String text,
      required Color? textColor,
      String? tooltip,
      GestureTapDownCallback? onTapDown}) {
    assert(!(onClick == null && onTapDown == null));
    Widget textWidget;
    if (icon != null) {
      textWidget = Text(
        translate(text),
        style: TextStyle(color: textColor),
        textAlign: TextAlign.center,
      );
    } else {
      textWidget = Expanded(
        child: Text(
          translate(text),
          style: TextStyle(color: textColor),
          textAlign: TextAlign.center,
        ),
      );
    }
    final borderRadius = BorderRadius.circular(10.0);
    final btn = Container(
      height: 28,
      decoration: BoxDecoration(
          color: color, borderRadius: borderRadius, border: border),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          if (onClick == null) return;
          checkClickTime(client.id, onClick);
        },
        onTapDown: (details) {
          if (onTapDown == null) return;
          checkClickTime(client.id, () {
            onTapDown.call(details);
          });
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Offstage(offstage: icon == null, child: icon).marginOnly(right: 5),
            textWidget,
          ],
        ),
      ),
    );
    return (tooltip != null
            ? Tooltip(
                message: translate(tooltip),
                child: btn,
              )
            : btn)
        .marginAll(4);
  }

  void handleDisconnect() {
    bind.cmCloseConnection(connId: client.id);
  }

  void handleAccept(BuildContext context) {
    final model = Provider.of<ServerModel>(context, listen: false);
    model.sendLoginResponse(client, true);
  }

  void handleElevate(BuildContext context) {
    final model = Provider.of<ServerModel>(context, listen: false);
    model.setShowElevation(false);
    bind.cmElevatePortable(connId: client.id);
  }

  void handleClose() async {
    await bind.cmRemoveDisconnectedConnection(connId: client.id);
    if (await bind.cmGetClientsLength() == 0) {
      windowManager.close();
    }
  }

  void handleSwitchBack(BuildContext context) {
    bind.cmSwitchBack(connId: client.id);
  }

  void handleVoiceCall(bool accept) {
    bind.cmHandleIncomingVoiceCall(id: client.id, accept: accept);
  }

  void closeVoiceCall() {
    bind.cmCloseVoiceCall(id: client.id);
  }
}

void checkClickTime(int id, Function() callback) async {
  if (allowRemoteCMModification()) {
    callback();
    return;
  }
  var clickCallbackTime = DateTime.now().millisecondsSinceEpoch;
  await bind.cmCheckClickTime(connId: id);
  Timer(const Duration(milliseconds: 120), () async {
    var d = clickCallbackTime - await bind.cmGetClickTime();
    if (d > 120) callback();
  });
}

bool allowRemoteCMModification() {
  return option2bool(kOptionAllowRemoteCmModification,
      bind.mainGetLocalOption(key: kOptionAllowRemoteCmModification));
}

class _FileTransferLogPage extends StatefulWidget {
  _FileTransferLogPage({Key? key}) : super(key: key);

  @override
  State<_FileTransferLogPage> createState() => __FileTransferLogPageState();
}

class __FileTransferLogPageState extends State<_FileTransferLogPage> {
  @override
  Widget build(BuildContext context) {
    return statusList();
  }

  Widget generateCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.all(
          Radius.circular(15.0),
        ),
      ),
      child: child,
    );
  }

  iconLabel(CmFileLog item) {
    switch (item.action) {
      case CmFileAction.none:
        return Container();
      case CmFileAction.localToRemote:
      case CmFileAction.remoteToLocal:
        return Column(
          children: [
            Transform.rotate(
              angle: item.action == CmFileAction.remoteToLocal ? 0 : pi,
              child: SvgPicture.asset(
                "assets/arrow.svg",
                colorFilter: svgColor(Theme.of(context).tabBarTheme.labelColor),
              ),
            ),
            Text(item.action == CmFileAction.remoteToLocal
                ? translate('Send')
                : translate('Receive'))
          ],
        );
      case CmFileAction.remove:
        return Column(
          children: [
            Icon(
              Icons.delete,
              color: Theme.of(context).tabBarTheme.labelColor,
            ),
            Text(translate('Delete'))
          ],
        );
      case CmFileAction.createDir:
        return Column(
          children: [
            Icon(
              Icons.create_new_folder,
              color: Theme.of(context).tabBarTheme.labelColor,
            ),
            Text(translate('Create Folder'))
          ],
        );
      case CmFileAction.rename:
        return Column(
          children: [
            Icon(
              Icons.drive_file_move_outlined,
              color: Theme.of(context).tabBarTheme.labelColor,
            ),
            Text(translate('Rename'))
          ],
        );
    }
  }

  Widget statusList() {
    return PreferredSize(
      preferredSize: const Size(200, double.infinity),
      child: Container(
          padding: const EdgeInsets.all(12.0),
          child: Obx(
            () {
              final jobTable = gFFI.cmFileModel.currentJobTable;
              statusListView(List<CmFileLog> jobs) => ListView.builder(
                    controller: ScrollController(),
                    itemBuilder: (BuildContext context, int index) {
                      final item = jobs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: generateCard(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: iconLabel(item),
                                  ).paddingOnly(left: 15),
                                  const SizedBox(
                                    width: 16.0,
                                  ),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.fileName,
                                        ).paddingSymmetric(vertical: 10),
                                        if (item.totalSize > 0)
                                          Text(
                                            '${translate("Total")} ${readableFileSize(item.totalSize.toDouble())}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: MyTheme.darkGray,
                                            ),
                                          ),
                                        if (item.totalSize > 0)
                                          Offstage(
                                            offstage: item.state !=
                                                JobState.inProgress,
                                            child: Text(
                                              '${translate("Speed")} ${readableFileSize(item.speed)}/s',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: MyTheme.darkGray,
                                              ),
                                            ),
                                          ),
                                        Offstage(
                                          offstage: !(item.isTransfer() &&
                                              item.state !=
                                                  JobState.inProgress),
                                          child: Text(
                                            translate(
                                              item.display(),
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: MyTheme.darkGray,
                                            ),
                                          ),
                                        ),
                                        if (item.totalSize > 0)
                                          Offstage(
                                            offstage: item.state !=
                                                JobState.inProgress,
                                            child: LinearPercentIndicator(
                                              padding:
                                                  EdgeInsets.only(right: 15),
                                              animateFromLastPercent: true,
                                              center: Text(
                                                '${(item.finishedSize / item.totalSize * 100).toStringAsFixed(0)}%',
                                              ),
                                              barRadius: Radius.circular(15),
                                              percent: item.finishedSize /
                                                  item.totalSize,
                                              progressColor: MyTheme.accent,
                                              backgroundColor:
                                                  Theme.of(context).hoverColor,
                                              lineHeight:
                                                  kDesktopFileTransferRowHeight,
                                            ).paddingSymmetric(vertical: 15),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [],
                                  ),
                                ],
                              ),
                            ],
                          ).paddingSymmetric(vertical: 10),
                        ),
                      );
                    },
                    itemCount: jobTable.length,
                  );

              return jobTable.isEmpty
                  ? generateCard(
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              "assets/transfer.svg",
                              colorFilter: svgColor(
                                  Theme.of(context).tabBarTheme.labelColor),
                              height: 40,
                            ).paddingOnly(bottom: 10),
                            Text(
                              translate("No transfers in progress"),
                              textAlign: TextAlign.center,
                              textScaler: TextScaler.linear(1.20),
                              style: TextStyle(
                                  color:
                                      Theme.of(context).tabBarTheme.labelColor),
                            ),
                          ],
                        ),
                      ),
                    )
                  : statusListView(jobTable);
            },
          )),
    );
  }
}
