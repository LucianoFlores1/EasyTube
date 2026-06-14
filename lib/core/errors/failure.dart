/// Typed failures surfaced to the UI layer.
sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión a internet.']);
}

class VideoUnavailableFailure extends Failure {
  const VideoUnavailableFailure([
    super.message = 'El video no está disponible o es privado.',
  ]);
}

class RegionBlockedFailure extends Failure {
  const RegionBlockedFailure([
    super.message = 'El video está bloqueado en tu región.',
  ]);
}

class ExtractionFailure extends Failure {
  const ExtractionFailure([
    super.message = 'No se pudieron obtener los formatos del video.',
  ]);
}

class DownloadFailure extends Failure {
  const DownloadFailure([super.message = 'La descarga falló.']);
}

class StorageFailure extends Failure {
  const StorageFailure([
    super.message = 'No se pudo acceder al almacenamiento.',
  ]);
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'Permiso denegado. Habilítalo en Ajustes.',
  ]);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Ocurrió un error inesperado.']);
}
