import 'package:flutter/material.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';

/// 个人中心 - NFT 列表（Alchemy NFT）
class NftListPage extends StatefulWidget {
  final String walletAddress;
  final String chain;

  const NftListPage({
    super.key,
    required this.walletAddress,
    this.chain = AlchemyService.ethMainnet,
  });

  @override
  State<NftListPage> createState() => _NftListPageState();
}

class _NftListPageState extends State<NftListPage> {
  final AlchemyService _alchemy = AlchemyService();
  bool _loading = true;
  String? _error;
  List<AlchemyNftItem> _nfts = [];
  String? _pageKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _error = null;
        if (!append) _nfts = [];
      });
    }
    try {
      final result = await _alchemy.getNfts(
        widget.walletAddress,
        chain: widget.chain,
        pageKey: append ? _pageKey : null,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = result.error;
        if (append) {
          _nfts.addAll(result.nfts);
        } else {
          _nfts = result.nfts;
        }
        _pageKey = result.pageKey;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFT'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: _loading && _nfts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _nfts.isEmpty
              ? _errorBody()
              : _gridBody(),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _load(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridBody() {
    if (_nfts.isEmpty) {
      return const EmptyStateView();
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _nfts.length + (_pageKey != null ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _nfts.length) {
            _load(append: true);
            return const Center(child: CircularProgressIndicator());
          }
          final nft = _nfts[i];
          return _nftCard(nft);
        },
      ),
    );
  }

  Widget _nftCard(AlchemyNftItem nft) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: nft.imageUrl != null && nft.imageUrl!.isNotEmpty
                ? Image.network(
                    nft.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              nft.name ?? 'NFT #${nft.tokenId}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
