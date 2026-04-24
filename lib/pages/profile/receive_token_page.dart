import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:education/services/alchemy_service.dart';

/// 网络选项（接收页可选网络，与 Token 页一致）
class _ReceiveNetworkOption {
  final String id;
  final String name;
  final Color iconColor;
  final IconData icon;

  const _ReceiveNetworkOption({
    required this.id,
    required this.name,
    required this.iconColor,
    this.icon = Icons.circle,
  });
}

/// 接收页：选择网络、展示二维码与地址，支持复制与分享
class ReceiveTokenPage extends StatefulWidget {
  final String walletAddress;
  final String initialChain;

  const ReceiveTokenPage({
    super.key,
    required this.walletAddress,
    this.initialChain = AlchemyService.bnbMainnet,
  });

  @override
  State<ReceiveTokenPage> createState() => _ReceiveTokenPageState();
}

class _ReceiveTokenPageState extends State<ReceiveTokenPage> {
  /// 与 Token 页一致；EVM 链（前四项）共用同一 0x 地址
  static const List<_ReceiveNetworkOption> _networks = [
    _ReceiveNetworkOption(id: AlchemyService.ethMainnet, name: 'Ethereum', iconColor: Color(0xFF627EEA), icon: Icons.diamond_outlined),
    _ReceiveNetworkOption(id: AlchemyService.bnbMainnet, name: 'BNB Chain', iconColor: Color(0xFFF3BA2F), icon: Icons.currency_bitcoin),
    _ReceiveNetworkOption(id: 'base-mainnet', name: 'Base', iconColor: Color(0xFF0052FF), icon: Icons.circle),
    _ReceiveNetworkOption(id: 'x-layer', name: 'X Layer', iconColor: Color(0xFF000000), icon: Icons.layers),
    _ReceiveNetworkOption(id: 'solana', name: 'Solana', iconColor: Color(0xFF9945FF), icon: Icons.link),
  ];

  static const Set<String> _evmChainIds = {
    AlchemyService.ethMainnet,
    AlchemyService.bnbMainnet,
    'base-mainnet',
    'x-layer',
  };

  late String _currentChain;

  @override
  void initState() {
    super.initState();
    final exists = _networks.any((n) => n.id == widget.initialChain);
    _currentChain = exists ? widget.initialChain : _networks.first.id;
  }

  _ReceiveNetworkOption get _currentNetwork =>
      _networks.firstWhere((n) => n.id == _currentChain, orElse: () => _networks.first);

  void _pickNetwork() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '请选择网络',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              ..._networks.map((n) {
                final selected = n.id == _currentChain;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: n.iconColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(n.icon, color: n.iconColor, size: 22),
                  ),
                  title: Text(n.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  trailing: selected ? const Icon(Icons.check, color: Color(0xFF00D1A7), size: 24) : null,
                  onTap: () {
                    setState(() => _currentChain = n.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: widget.walletAddress));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _shareAddress() async {
    try {
      await Share.share(
        widget.walletAddress,
        subject: '${_currentNetwork.name} 收款地址',
      );
    } on MissingPluginException catch (_) {
      // 原生未注册 share（如热重载后未完全重启）：回退为复制并提示
      await Clipboard.setData(ClipboardData(text: widget.walletAddress));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享不可用，已复制地址，可粘贴到 Discord 等应用')),
        );
      }
    } on Exception catch (e) {
      await Clipboard.setData(ClipboardData(text: widget.walletAddress));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败，已复制地址：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final network = _currentNetwork;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '接收',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // 说明：EVM 链共用同一地址
              Text(
                'EVM 链（以太坊、BNB Chain、Base、X Layer）共用同一地址，切换网络仅用于标识收款链。',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 网络选择
              GestureDetector(
                onTap: _pickNetwork,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: network.iconColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(network.icon, color: network.iconColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        network.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_arrow_down, size: 22, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // 二维码（中心可放小 logo）
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: widget.walletAddress,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // 地址卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${network.name} 地址',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      widget.walletAddress,
                      style: const TextStyle(
                        fontSize: 15,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 警告文案（EVM 链强调链标识；Solana 提示地址格式不同）
              Text(
                _evmChainIds.contains(_currentChain)
                    ? '*请确保对方从${network.name}向该地址转账，误发到其他链可能导致资产丢失'
                    : '*当前为 EVM 格式地址，Solana 使用不同地址，请勿向本地址转入 SOL',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              // 复制 / 分享
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyAddress,
                      icon: const Icon(Icons.copy, size: 20),
                      label: const Text('复制'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareAddress,
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text('分享'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
