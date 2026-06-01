import 'dart:math';

class ProphetRoutingService {
  static const double PEncMax = 0.5;
  static const double I_TYP = 1800;
  static const double GAMMA = 0.999885791;
  static const double DEFAULT_BETA = 0.9;

  final int secondsInTimeUnit = 30;
  final double beta = DEFAULT_BETA;

  final Map<String, double> preds = {};
  final Map<String, double> lastEncounterTime = {};

  double lastAgeUpdate = 0;

  double _now() => DateTime.now().millisecondsSinceEpoch / 1000.0;

   
  void updateDeliveryPred(String peerId) {
    double now = _now();
    double lastTime = lastEncounterTime[peerId] ?? 0;

    double pEnc;

    if (lastTime == 0) {
      pEnc = PEncMax;
    } else if ((now - lastTime) < I_TYP) {
      pEnc = PEncMax * ((now - lastTime) / I_TYP);
    } else {
      pEnc = PEncMax;
    }

    double old = preds[peerId] ?? 0;
    double updated = old + (1 - old) * pEnc;

    preds[peerId] = updated;
    lastEncounterTime[peerId] = now;
  }

 // Transitivity (A → B → C)
  void updateTransitivePreds(
      String peerId, Map<String, double> peerPreds) {
    double pAB = getPred(peerId);

    for (var entry in peerPreds.entries) {
      String c = entry.key;
      double pBC = entry.value;

      double old = getPred(c);
      double pNew = pAB * pBC * beta;

      if (pNew > old) {
        preds[c] = pNew;
      }
    }
  }

  double getPred(String nodeId) {
    agePreds();

    return preds[nodeId] ?? 0;
  }

  void agePreds() {
    double now = _now();
    double timeDiff = (now - lastAgeUpdate) / secondsInTimeUnit;

    if (timeDiff <= 0) return;

    double mult = pow(GAMMA, timeDiff).toDouble();

    preds.updateAll((key, value) => value * mult);

    lastAgeUpdate = now;
  }
}