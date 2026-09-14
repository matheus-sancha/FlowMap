# FlowMap — signing the drop

Why Windows blocks `flowmap.exe`, what actually removes the block, and which certificate to buy.
Read with `README.md` ("Shipping a drop") and `tool/package_windows.ps1`, which does the signing.

---

## 1. What Windows is doing

**"Windows protected your PC — Unknown publisher" is SmartScreen, and it is one question: who
signed this?** Not *is this malware*. `flowmap.exe` carries no Authenticode signature at all, so
Windows has no publisher to name and no reputation record to look up, and it stops the launch
behind a *More info → Run anyway* that most people read as a virus warning.

Two facts decide whether the prompt appears:

- **The mark of the web.** A browser writes a `Zone.Identifier` stream onto anything it downloads.
  Explorer's own unzip **copies that mark onto every extracted file**, so `flowmap.exe` arrives
  marked as coming from the internet, and that mark is what arms SmartScreen on launch. Clear the
  mark from the zip *before* unzipping — right-click, Properties, Unblock — and the extracted exe
  carries none, and SmartScreen does not run. This is why `READ ME FIRST.txt` now opens with it.
- **Reputation is per certificate, not per file.** An unsigned build starts from nothing on every
  machine and every new drop. A signed one accumulates, across drops, under one identity.

**So there are two blocks, not one, and they need different answers.** Unblocking the zip handles
the download mark and costs nothing. Only a signature handles the publisher question, and only a
signature survives someone copying the exe off a shared drive, which carries no mark at all and
where the app still reads as authored by nobody.

_Rejected: telling people to turn SmartScreen off._ It is the setting that protects them from the
next unsigned exe, and on a managed plant PC it is not theirs to turn off anyway.

_Rejected: leaving `READ ME FIRST.txt` as the whole answer._ It already said "click Run anyway",
and the block was still reported from the field. A warning a user must be talked past is a warning
that gets the app deleted the one time nobody is there to talk them past it.

---

## 2. What the exe says about itself

`windows/runner/Runner.rc` carried Flutter's template strings: company `com.sancha`, product
`flowmap`, description `flowmap`. It now reads `Matheus Sancha` / `FlowMap` / a real description,
and `pubspec.yaml` carries the drop's version rather than Flutter's `0.1.0` default, so
Properties → Details and every allow-list tool read the same version the release page does.

**None of this removes the SmartScreen prompt** — an unsigned file is unsigned whatever it claims —
and it is worth saying plainly so nobody mistakes it for the fix. What it does is make the file
defensible when someone in IT opens its properties, and it is what a publisher rule matches on.
**`CompanyName` must be written exactly as the subject name on the certificate**, or a signed build
still reads as one identity claiming to be another.

---

## 3. Which certificate

All three routes end at the same place: `signtool` puts a signature on `flowmap.exe` that chains to
a root Windows already trusts. They differ in price, in what has to be proved, and in what has to
be carried around.

| | Azure Trusted Signing | OV certificate | EV certificate |
|---|---|---|---|
| Roughly | ~$10/month | ~$200–400/year | ~$400–700/year |
| Key lives | Microsoft's HSM | hardware token or cloud HSM | hardware token or cloud HSM |
| To sign | Azure credentials | the token in the machine | the token in the machine |
| Identity proved | by Microsoft | by the CA | by the CA, more strictly |
| SmartScreen at first drop | still warns until reputation builds | still warns until reputation builds | usually clears fastest |

**Recommended: Azure Trusted Signing.** It is an order of magnitude cheaper, there is no token to
lose or to be holding when a drop has to go out, and the signing certificates are short-lived and
reissued per signature — which is why every signature must be timestamped, and why the packaging
script refuses to sign without a timestamp URL. Eligibility is the catch worth checking before
counting on it: it asks for a verifiable legal identity, and the organisation route wants a few
years of verifiable existence; there is an individual route. **Confirm current pricing and
eligibility with Microsoft before deciding** — both have moved since this was written.

**EV is what to buy if the first drop must land clean on twenty machines at once**, because it is
the route that most often carries reputation from the start. It is also the most expensive and the
one that puts a USB token in the release process.

**Since June 2023 no route lets the private key sit in a file on the build machine.** Code-signing
keys must live in certified hardware, so "a `.pfx` in the repo" is not an option any public CA will
sell. `-CertificatePath` stays in the script for an internal CA (below) and for test signing.

_Rejected: a self-signed certificate._ It changes nothing for a user: their machine does not trust
the root, so SmartScreen is unchanged and Properties now shows a signature that fails to verify,
which is worse than none. It is only useful if IT deploys the root to every machine — which is the
internal route below, and then the certificate should come from the company's own CA, not from us.

---

## 4. The route that may beat buying anything

**FlowMap goes to about twenty machines inside one company.** That changes the arithmetic: the
company's own IT can make the app trusted on exactly those machines, for nothing, and more strongly
than a public certificate would.

- **An allow-list entry by hash.** WDAC or AppLocker takes the SHA-256 the packaging script prints.
  It is exact, and it has to be redone every drop.
- **An allow-list entry by publisher.** The same tools take a certificate subject, and then every
  future drop signed by the same identity is covered with no new work. This needs a signature —
  from a public CA or from the company's internal PKI, which can issue one at no cost and is
  already trusted on every domain-joined machine.
- **The internal certificate covers domain machines only.** A consultant's laptop or a colleague at
  another plant is back to the prompt, which is the reason not to treat it as the whole answer if
  the audience will ever widen.

**Ask IT before buying.** If the answer is an internal code-signing certificate, `-CertificatePath`
or `-CertificateThumbprint` already takes it and the cost is a conversation.

_Also worth knowing:_ if it is **Defender** flagging the file rather than SmartScreen naming the
publisher, that is a different product and a different fix — submit the zip to Microsoft as a false
positive, which is free and usually turned around in a day.

---

## 5. Signing a drop, once there is a certificate

`tool/package_windows.ps1` signs the staged folder between assembling it and zipping it, so a
failed signature means no zip rather than an unsigned one handed out by mistake.

```powershell
# Azure Trusted Signing
powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1 -Label 2.1.3-2026-09-20 -Tag v2.1.3 `
  -AzureSignDlib C:\ats\bin\x64\Azure.CodeSigning.Dlib.dll -AzureSignMetadata C:\ats\metadata.json

# A token, or any certificate in the current user's store
... -CertificateThumbprint A1B2C3D4E5F6...

# A .pfx. The password comes from $env:FLOWMAP_CERT_PASSWORD, or is prompted for,
# so it never reaches the shell history.
... -CertificatePath C:\certs\flowmap.pfx
```

What it does, and why each part is not optional:

- **`flowmap.exe` and every unsigned DLL beside it are signed.** SmartScreen weighs only the file
  the user launches, but a publisher allow-list rule is written against the folder, and one
  unsigned DLL in it is one exception IT has to write by hand.
- **The Visual C++ runtime DLLs are left alone.** They already carry Microsoft's signature, and
  re-signing would replace it with ours.
- **Every signature is timestamped** (`/tr`, SHA-256). Without a countersignature, every drop ever
  shipped stops verifying the day the certificate expires.
- **It verifies with `signtool verify /pa`** — the Authenticode policy, the one Windows itself
  applies — so a certificate that signs but does not chain to a trusted root fails on the build
  machine instead of on twenty plant PCs.
- **`-Label` must agree with `version:` in `pubspec.yaml`**, or the script refuses: that version is
  what Windows reads off the file, and an allow-list written against the wrong one is wrong.

**It still packages unsigned**, printing what that costs, because a drop must not be blocked on a
purchase order.

---

## 6. What to expect the first time

**A signature does not switch the warning off on the day it is bought.** Reputation accrues to the
certificate as copies are downloaded and run without incident, and the first signed drop may still
prompt — now naming a publisher instead of refusing to name one, which is already the difference
between "unknown" and a company employee reading their own employer's name.

So the first signed drop still ships with the unblock instruction in `READ ME FIRST.txt`, and the
release notes still carry the SHA-256. Drop the guidance when a drop reaches a fresh machine
without a prompt, not before — and record that machine, because it is the same cold-install
evidence phase 7 is still owed.
