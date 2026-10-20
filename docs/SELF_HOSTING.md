# Run your own backend and relayer

You don't need this to try Canary: `flutter run` uses the hosted devnet backend. Follow these steps
only to run Canary on your own Supabase project with your own Solana relayer key. Devnet only.

You need: the [Supabase CLI](https://supabase.com/docs/guides/cli), Deno 2.x, the
[Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools) (for `solana-keygen`), and a
Supabase project you own.

## 1. Link the project

```bash
cd app
supabase link --project-ref <your-project-ref>
```

## 2. Create the tables

Apply only the two Canary migrations. Don't run `supabase db push`: the rest of
`app/supabase/migrations/` belongs to the full NO SUS app.

```bash
supabase db query --linked --file supabase/migrations/20260919090000_nosus_canary.sql
supabase db query --linked --file supabase/migrations/20261010090000_nosus_canary_solana.sql
```

## 3. Make and fund a devnet relayer key

```bash
solana-keygen new --no-bip39-passphrase --outfile ~/.config/nosus/relayer-devnet.json
solana-keygen pubkey ~/.config/nosus/relayer-devnet.json
```

Fund that address with devnet SOL at https://faucet.solana.com. Each receipt costs 0.000005 SOL,
so 1 SOL covers about 200,000 receipts. Keep the key file outside the repo.

## 4. Set the function secrets

```bash
supabase secrets set --project-ref <your-project-ref> \
  CANARY_TAG_SALT="$(openssl rand -hex 32)" \
  SOLANA_RELAYER_KEYS="$(cat ~/.config/nosus/relayer-devnet.json | tr -d ' \n')" \
  SOLANA_RPC_URL=https://api.devnet.solana.com
```

`SOLANA_RELAYER_KEYS` takes up to 32 comma-separated keys, each a base58 secret key or a
`solana-keygen` JSON array. Every secret is listed in [../.env.example](../.env.example).

## 5. Bundle and deploy the function

The function imports `packages/receipts-ts`, which is outside `app/`, so bundle it into one file
first and deploy the bundle from a scratch folder:

```bash
cd ..   # repo root
mkdir -p /tmp/canary-deploy/supabase/functions/canary
deno bundle --platform=deno app/supabase/functions/canary/index.ts \
  -o /tmp/canary-deploy/supabase/functions/canary/index.ts
supabase functions deploy canary --project-ref <your-project-ref> \
  --no-verify-jwt --use-api --workdir /tmp/canary-deploy
```

`--no-verify-jwt` is required: callers send only the publishable key.

## 6. Point the app at your project

Set `url` and `anonKey` (your publishable key) in `app/lib/config/supabase_credentials.dart`, then:

```bash
cd app
flutter run -d chrome --dart-define=NOSUS_CANARY_ONLY=true
# or a static build for any host, served under /nosus-canary/:
flutter build web --release --base-href /nosus-canary/ --dart-define=NOSUS_CANARY_ONLY=true
```

## 7. Check it end to end

Create a link, open it in a private window, and click the **Solana** chip. Explorer must show one
Memo instruction whose text starts with `{"p":"nosus-canary","v":1,"t":"open"` and holds hashes
only. Or decode it from the terminal:

```bash
deno run --allow-net packages/receipts-ts/cli.ts <signature>
```
