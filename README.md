# Hasaad — حصاد

> Smart farming decisions, powered by data and AI.

Hasaad is a Flutter application built for farmers in Saudi Arabia. It aggregates nationwide crop supply, demand, and pricing data, then layers AI-driven recommendations on top so each farmer can make better planting, financial, and harvesting decisions based on their own land and the broader market.

---

## Features

- **Nationwide analytics** — browse crop supply and demand trends across all governorates, with interactive charts showing historical and current market data.
- **AI assistant** — ask questions or get personalised recommendations based on your farm profile and crop data.
- **Price & yield predictions** — AI-powered forecasts for crop prices, expected yields, profit margins, and optimal land allocation.
- **Farm management** — track your plots, log financial records (income and expenses), and manage planting plans with a built-in calendar.
- **Reminders & notifications** — schedule farming tasks and receive local notifications so nothing slips.
- **Bilingual** — full Arabic and English localisation (RTL supported).

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State management | Riverpod |
| Backend / Auth | Supabase |
| Charts | fl_chart |
| Location | Geolocator |
| Localisation | Flutter Localizations (`intl`) |
| Code generation | Freezed · json_serializable · Riverpod generator |

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.0`
- Dart SDK (bundled with Flutter)
- A Supabase project (for backend and auth)

### Setup

```bash
# Clone the repository
git clone https://github.com/awsaz-git/hasaad-client.git
cd hasaad-client

# Install dependencies
flutter pub get

# Copy the environment template and fill in your Supabase credentials
cp .env.example .env

# Run code generation
dart run build_runner build --delete-conflicting-outputs

# Launch the app
flutter run
```

### Environment variables

Create a `.env` file at the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

---

## Project Structure

```
lib/
├── main.dart
├── models/        # Freezed data models (crops, plans, financials, …)
├── screens/       # One file per screen
├── services/      # Supabase, weather, and notification services
├── utils/         # Theme, localisation helpers, validators
└── widgets/       # Shared UI components
assets/
├── l10n/          # ARB and JSON translation files (ar / en)
└── …              # Images, splash, icons
```

---

## Supported Platforms

Android · iOS · Web · macOS · Linux · Windows (Flutter multi-platform build)

---

## License

See [LICENSE.txt](LICENSE.txt).
