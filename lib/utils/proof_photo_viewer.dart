import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';

Map<String, dynamic>? latestProofPhotoFromRecord(Map<String, dynamic> record) {
  final photos = record['collection_proof_photos'];
  if (photos is List && photos.isNotEmpty) {
    return Map<String, dynamic>.from(photos.first as Map);
  }
  return null;
}

bool recordHasProofPhoto(Map<String, dynamic> record) {
  return latestProofPhotoFromRecord(record) != null ||
      record['photoAdded'] == true;
}

Future<void> showProofPhotoDialog(
  BuildContext context,
  Map<String, dynamic> record,
) async {
  final recordId = (record['id'] as num?)?.toInt();
  if (recordId == null) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final proof =
        latestProofPhotoFromRecord(record) ??
        await SupabaseService.getLatestProofPhoto(recordId);

    if (proof == null) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No proof photo found for this record.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final imageUrl = await SupabaseService.createProofPhotoSignedUrl(proof);
    final proofId = (proof['id'] as num?)?.toInt();
    if (proofId != null) {
      await SupabaseService.markProofPhotoViewed(proofId);
    }

    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Proof Photo - Record #$recordId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 360,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 320,
                      child: Center(child: Text('Could not load proof photo.')),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Uploaded: ${proof['uploaded_at'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open proof photo: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
