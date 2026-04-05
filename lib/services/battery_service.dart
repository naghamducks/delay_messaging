class BatteryService {
  double energy = 10800;

  static const double txEnergy = 0.000005;
  static const double rxEnergy = 0.000003;
  static const double scanEnergy = 0.001;

  void consumeTx(double size) {
    energy -= size * txEnergy;
  }

  void consumeRx(double size) {
    energy -= size * rxEnergy;
  }

  void consumeScan() {
    energy -= scanEnergy;
  }

  bool isAlive() => energy > 0;
}