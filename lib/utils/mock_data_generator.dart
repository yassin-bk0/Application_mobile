import '../models/pv_data.dart';
import '../services/fake_data_service.dart';

/// @deprecated
/// Utiliser [FakeDataService] à la place.
///
/// Cette classe est conservée uniquement pour compatibilité ascendante.
/// Elle délègue maintenant à [FakeDataService] (déterministe, sans Random pur).
@Deprecated('Utiliser FakeDataService.generateForTime() à la place.')
class MockDataGenerator {
  /// @deprecated — Utiliser [FakeDataService.generateForTime] à la place.
  @Deprecated('Utiliser FakeDataService.generateForTime() à la place.')
  static PvData generateForTime(DateTime time) {
    return FakeDataService.generateForTime(time);
  }
}
