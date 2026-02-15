# axiom_flutter

**The Flutter bindings for AxiomCore.**

`axiom_flutter` provides a robust, Rust-powered runtime for managing **Server State** in Flutter applications. It connects your UI directly to [AxiomCore](https://github.com/AxiomCore), allowing you to execute API contracts with cryptographic safety, automatic caching, and request deduplication.

---

## ❓ Why AxiomCore?

Modern mobile development suffers from the **"Network-UI Gap"**.
1.  **Fragility:** APIs change, but mobile apps update slowly. This leads to runtime crashes when JSON schemas drift.
2.  **Boilerplate:** Developers write thousands of lines of `isLoading`, `isError`, and JSON serialization code.
3.  **State Confusion:** Developers often stuff API caching logic into UI state managers (Bloc/Provider/Riverpod), leading to race conditions and memory leaks.

**Axiom solves this by moving the network layer into a pre-compiled, verified Contract.**

### How it works
1.  **Define** your API in a schema (Axiom Contract).
2.  **Generate** the client code.
3.  **Run** the `AxiomRuntime` (powered by Rust) in your app.

The Rust core handles serialization, validation, caching, and networking. Flutter simply consumes the resulting Stream.

---

## 🧠 Server State vs. UI State

To use Axiom effectively, it is helpful to understand the distinction between the two types of state in an application.

| UI State (Use Provider/Bloc/Riverpod) | Server State (Use Axiom) |
| :--- | :--- |
| **Synchronous** | **Asynchronous** (Requires latency) |
| **Client-Owned** (Dropdown open, form input) | **Remote-Owned** (Database data, User Profile) |
| **Ephemeral** (Reset on restart) | **Persistent** (Outlives the session) |
| **Deterministic** | **Stale** (Can change without you knowing) |

`axiom_flutter` is designed **strictly for Server State**. It handles the complexity of "Stale-While-Revalidate", optimistic updates, and background refetching so your UI State managers don't have to.

---

## ✨ Key Features

*   **Rust-Powered Runtime:** Uses `dart:ffi` to communicate with a high-performance Rust core.
*   **Smart Caching:** Automatic cache persistence and invalidation. If data exists in the Sled cache (managed by Rust), it is shown immediately while the network request updates in the background.
*   **Request Deduplication:** If two widgets request the same data simultaneously, Axiom only sends one network request and broadcasts the result to both.
*   **Rich Error Handling:** Errors are categorized (`Network`, `Auth`, `Contract`, `Timeout`) and include retry strategies.
*   **Deterministic Query Keys:** Arguments are normalized and sorted. `{a: 1, b: 2}` generates the same cache key as `{b: 2, a: 1}`.

---

## 📦 Installation

Add `axiom_flutter` to your `pubspec.yaml`. You will also need the compiled Rust libraries (handled by your project setup or the Axiom CLI).

```yaml
dependencies:
  axiom_flutter: ^0.0.1
  path_provider: ^2.0.0
```

## 🚀 Initialization

Before using any queries, initialize the runtime. This usually happens in `main.dart`.

```dart
import 'package:axiom_flutter/axiom_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load your contract bytes (usually an asset)
  final contractBytes = await loadContractAsset(); 

  // 2. Start the Rust Runtime
  await AxiomRuntime().startup(
    baseUrl: "https://api.myapp.com",
    contractBytes: contractBytes,
    // optional: signature and publicKey for contract verification
  );

  runApp(const MyApp());
}
```

---

## 🛠 Usage

### 1. The `AxiomBuilder` Widget

The generic way to consume data is using `AxiomBuilder`. It handles the stream subscription, initial loading state, and error states for you.

```dart
class UserProfile extends StatelessWidget {
  final int userId;

  const UserProfile({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // 1. Create the query (Usually generated code)
    final query = MyApi.getUser(id: userId);

    return AxiomBuilder<User, User>(
      query: query,
      // 2. Optional: Select specific data to prevent unnecessary rebuilds
      selector: (user) => [user.name, user.avatarUrl],
      
      // 3. Handle Loading (Optional, defaults to SizedBox)
      loading: (context) => const CircularProgressIndicator(),
      
      // 4. Handle Error (Optional, defaults to Text)
      error: (context, error) => Text(error.message),

      // 5. Build Data
      builder: (context, state, user) {
        return Column(
          children: [
            if (state.isFetching) const LinearProgressIndicator(), // Show background refresh
            Text(user.name),
            Image.network(user.avatarUrl),
          ],
        );
      },
    );
  }
}
```

### 2. Manual Stream Usage

You can use the query stream directly in your BLoCs or Providers.

```dart
final query = MyApi.getDashboard();

// Listen to the stream
query.stream.listen((state) {
  if (state.hasData) {
    print("Got data from ${state.source}: ${state.data}");
  }
});

// Force a refresh from network
query.refresh();
```

### 3. One-shot Futures (Extensions)

Sometimes you just want a Future (e.g., on a button press), not a stream. `axiom_flutter` provides extension methods for this.

```dart
void onRefreshPressed() async {
  try {
    // .unwrap() waits for the first valid data or throws an error
    final data = await MyApi.getDashboard().stream.unwrap();
    print("Refreshed: $data");
  } catch (e) {
    print("Failed: $e");
  }
}
```

---

## ⚙️ Architecture Deep Dive

### Query Management & Keys
Inside `lib/src/query_manager.dart`, Axiom maintains a `Map<String, ActiveQuery>`.

When you request a query:
1.  **Normalization:** The arguments are sorted alphabetically (see `AxiomQueryKey` in `query_key.dart`).
2.  **Key Generation:** A unique string key is built (e.g., `endpoint_42:{"id":10}`).
3.  **Lookup:**
    *   If an `ActiveQuery` exists for that key, you get a subscription to the **existing** stream.
    *   If not, a new FFI call is made to Rust, and a new Stream is created.

This ensures that if 5 different widgets request `User(id: 1)`, only **one** network request is sent, and all 5 widgets update simultaneously.

### The FFI Boundary
Communication happens via `dart:ffi`.
1.  **Request:** Dart serializes the request body to `Uint8List` and passes pointers to C++.
2.  **Processing:** Rust processes the request (Cache lookup -> Network -> Cache Write).
3.  **Response:** Rust invokes a C-function pointer callback registered by Dart.
4.  **Isolate Communication:** The callback sends data via a `SendPort` to the main Flutter isolate to ensure thread safety.

### Error Handling
Axiom returns rich error objects defined in `state.dart`. You can check:
*   `stage`: Did it fail during `cacheRead`, `networkSend`, or `deserialize`?
*   `category`: Is it a `network` issue, `auth` issue, or `validation` issue?
*   `retryable`: Does the Rust core recommend retrying?

---

## 🛡 Security

Axiom contracts can be signed. If you provide a `signature` and `publicKey` during `startup`, the Rust core will cryptographically verify that the API definition hasn't been tampered with.

If the contract is unsigned, `AxiomRuntime` will print a security warning to the console in debug mode.

---

## License

MIT