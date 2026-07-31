import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

class LiveProductionDCWidget extends StatelessWidget {
  final String userId;
  final String installationId;

  const LiveProductionDCWidget({
    Key? key,
    required this.userId,
    required this.installationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Le chemin exact vers la collection contenant les données en temps réel.
    // Vérifiez bien que vos règles Firestore (Security Rules) autorisent la lecture (read) sur ce chemin.
    final collectionPath = 'users/$userId/installations/$installationId/real_time';

    return StreamBuilder<QuerySnapshot>(
      // 1. Utilisation de snapshots() au lieu de get()
      //    Cela crée une écoute en temps réel. Dès qu'un document est ajouté ou modifié
      //    dans la collection, le StreamBuilder se mettra à jour automatiquement.
      // 2. On trie par 'timestamp' décroissant et on prend le plus récent (limit 1).
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // 3. Gérer l'état de chargement
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }

        // 4. Gérer les erreurs (ex: permissions manquantes, hors ligne)
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }

        // 5. Gérer le cas où les données sont nulles ou la collection est vide
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aucune donnée de production.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          );
        }

        // 6. Récupérer le champ productionDC du document le plus récent
        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        // Sécuriser la lecture de productionDC (fallback à 0.0 si le champ n'existe pas ou est null)
        final double productionDC = (data['productionDC'] as num?)?.toDouble() ?? 0.0;

        // 7. Affichage UI dynamique
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.solar_power_rounded, color: Colors.blueAccent, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Production DC (Live)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Petit indicateur clignotant pour montrer que c'est "Live"
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    FormatUtils.formatPowerValue(productionDC),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'kW',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
