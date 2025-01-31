# wo_form_service

An implementation of services from wo_form.

## Features

- Implements MediaInput with MediaField & WoMediaService
- Beautiful date pickers whith DateTimeService

## Getting started

To use WoMediaService, extend it with the features of your choice.

```dart
class WoMediaServiceImpl extends WoMediaService {
  const WoMediaServiceImpl({required super.permissionService});

  ...
}
```

## Usage

Provide the services you need with the following code above your MaterialApp.

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MediaService>(
          create: (context) => WoMediaServiceImpl(
            permissionService: context.read(),
            // storageRepository: context.read(),
          ),
        ),
        RepositoryProvider<WoMediaService>(
          create: (context) =>
              context.read<MediaService>() as WoMediaServiceImpl,
        ),
        RepositoryProvider(create: (context) => const DateTimeService()),
      ],
      child: MaterialApp(), // Your app here
    );
  }
}

```
