/// Sawa kabisa na compute_member_status() na build_sms_text() za Python.
class DebtStatus {
  final double kiwangoMwezi;
  final double kianzioDeduction;
  final double deniMichangoLinalotarajiwa;
  final double kianzioDeni;
  final double deniMichangoLililobaki;
  final double jumlaDeni;
  final double ziada;
  final double miezyZiada;

  DebtStatus({
    required this.kiwangoMwezi,
    required this.kianzioDeduction,
    required this.deniMichangoLinalotarajiwa,
    required this.kianzioDeni,
    required this.deniMichangoLililobaki,
    required this.jumlaDeni,
    required this.ziada,
    required this.miezyZiada,
  });
}

class DebtCalculator {
  static const Map<String, double> genderMonthlyRate = {'ME': 5000, 'KE': 2500};
  static const double kianzioKiasi = 18000;

  static DebtStatus computeMemberStatus({
    required double mchangoJumla,
    required String kianzioHali,
    required String gender,
    required int idadiYaMiezi,
  }) {
    final kianzioStr = kianzioHali.trim().toUpperCase();
    final kianzioDeduction = kianzioStr == 'HAHUSIKI' ? 0.0 : kianzioKiasi;

    final kiwangoMwezi = genderMonthlyRate[gender] ?? genderMonthlyRate['ME']!;
    final deniMichangoLinalotarajiwa = kiwangoMwezi * idadiYaMiezi;

    final kianzioDeni = (kianzioDeduction - mchangoJumla).clamp(0.0, double.infinity);
    final adaBaadaYaKianzio = (mchangoJumla - kianzioDeduction).clamp(0.0, double.infinity);

    double deniMichangoLililobaki;
    double ziada;
    if (adaBaadaYaKianzio >= deniMichangoLinalotarajiwa) {
      deniMichangoLililobaki = 0.0;
      ziada = adaBaadaYaKianzio - deniMichangoLinalotarajiwa;
    } else {
      deniMichangoLililobaki = deniMichangoLinalotarajiwa - adaBaadaYaKianzio;
      ziada = 0.0;
    }

    final jumlaDeni = kianzioDeni + deniMichangoLililobaki;
    final miezyZiada = kiwangoMwezi != 0 ? ziada / kiwangoMwezi : 0.0;

    return DebtStatus(
      kiwangoMwezi: kiwangoMwezi,
      kianzioDeduction: kianzioDeduction,
      deniMichangoLinalotarajiwa: deniMichangoLinalotarajiwa,
      kianzioDeni: kianzioDeni,
      deniMichangoLililobaki: deniMichangoLililobaki,
      jumlaDeni: jumlaDeni,
      ziada: ziada,
      miezyZiada: miezyZiada,
    );
  }

  static String buildSmsText(
    String jina,
    double depositRun,
    int idadiYaMiezi,
    DebtStatus status,
  ) {
    final buf = StringBuffer();
    if (depositRun > 0) {
      buf.write('Ndugu $jina, tumepokea Deposit ya TZS ${_fmt(depositRun)}.');
    } else {
      buf.write('Ndugu $jina,');
    }

    if (status.jumlaDeni > 0) {
      final kianzioNote =
          status.kianzioDeni > 0 ? ' (ikiwemo Kianzio TZS ${_fmt(status.kianzioDeni)})' : '';
      buf.write(
          ' Deni lako lililobaki JUMLA ni TZS ${_fmt(status.jumlaDeni)} kwa miezi $idadiYaMiezi$kianzioNote.');
    } else if (status.ziada > 0) {
      buf.write(
          ' Umeshalipa deni lako lote kwa miezi $idadiYaMiezi na una ziada ya TZS ${_fmt(status.ziada)} '
          '(sawa na miezi ${status.miezyZiada.toStringAsFixed(1)}). Hongera!');
    } else {
      buf.write(' Huna deni lolote kwa sasa kwa miezi $idadiYaMiezi. Hongera!');
    }
    return buf.toString();
  }

  static String _fmt(double v) {
    // Umbizo la "1,234" sawa na Python's f"{x:,.0f}"
    final intVal = v.round();
    final s = intVal.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
