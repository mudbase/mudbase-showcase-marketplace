import 'package:dio/dio.dart';
import 'package:mudbase_showcase_marketplace/core/mudbase_exception.dart';
import 'package:test/test.dart';

void main() {
  group('MudbaseException.fromDioException', () {
    test('reads the server "error" field and status code from a response', () {
      final requestOptions = RequestOptions(path: '/api/data/x');
      final dioError = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 403,
          data: {'error': 'Insufficient permissions'},
        ),
        type: DioExceptionType.badResponse,
      );

      final exception = MudbaseException.fromDioException(dioError);

      expect(exception.message, 'Insufficient permissions');
      expect(exception.statusCode, 403);
    });

    test('falls back to "message" when "error" is absent', () {
      final requestOptions = RequestOptions(path: '/api/data/x');
      final dioError = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'message': 'Validation failed'},
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        MudbaseException.fromDioException(dioError).message,
        'Validation failed',
      );
    });

    test('reads an optional "code" field for programmatic branching', () {
      final requestOptions = RequestOptions(path: '/api/auth/local/login');
      final dioError = DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 403,
          data: {
            'error': 'Email verification required',
            'code': 'EMAIL_VERIFICATION_REQUIRED',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        MudbaseException.fromDioException(dioError).code,
        'EMAIL_VERIFICATION_REQUIRED',
      );
    });

    test(
      'produces a friendly message for a connection timeout with no response',
      () {
        final requestOptions = RequestOptions(path: '/api/data/x');
        final dioError = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );

        final exception = MudbaseException.fromDioException(dioError);
        expect(exception.statusCode, 0);
        expect(exception.message, contains('timed out'));
      },
    );

    test(
      'produces a friendly message for a connection error with no response',
      () {
        final requestOptions = RequestOptions(path: '/api/data/x');
        final dioError = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        );

        expect(
          MudbaseException.fromDioException(dioError).message,
          contains("Couldn't reach the server"),
        );
      },
    );

    test('toString() returns the message', () {
      const exception = MudbaseException('Boom', 500);
      expect(exception.toString(), 'Boom');
    });
  });
}
