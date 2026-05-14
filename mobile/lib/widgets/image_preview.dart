import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void showLocalImagePreview(BuildContext context, XFile image) {
  showDialog(
    context: context,
    builder: (context) => _ImagePreviewDialog(
      title: image.name,
      child: Image.file(File(image.path), fit: BoxFit.contain),
    ),
  );
}

class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black87,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: child,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: '关闭',
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalImageTile extends StatelessWidget {
  const LocalImageTile({
    super.key,
    required this.image,
    required this.size,
    this.onRemove,
  });

  final XFile image;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showLocalImagePreview(context, image),
            child: Image.file(
              File(image.path),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 15, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class SelectedImagesPreview extends StatelessWidget {
  const SelectedImagesPreview({
    super.key,
    required this.images,
    this.onRemove,
  });

  final List<XFile> images;
  final ValueChanged<XFile>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '待上传图片（点按可查看大图）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final image = images[index];
              return LocalImageTile(
                image: image,
                size: 82,
                onRemove: onRemove == null ? null : () => onRemove!(image),
              );
            },
          ),
        ),
      ],
    );
  }
}
