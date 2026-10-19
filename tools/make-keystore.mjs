// Creates the store's signing key (PKCS12) without needing Java installed.
// Usage: node tools/make-keystore.mjs <output-dir>
// Writes keystore.p12, keystore.b64 (for the GitHub secret), secrets.env and fingerprint.txt.
// BACK UP THE OUTPUT DIR: if the key is lost, every phone has to remove and re-add the store.
import { generateKeyPairSync, randomBytes, createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import forge from 'node-forge';

const outDir = resolve(process.argv[2] ?? '../appbutik-secrets');
const alias = 'appbutik';

if (existsSync(join(outDir, 'keystore.p12'))) {
  console.error(`Refusing to overwrite ${join(outDir, 'keystore.p12')} — the existing key is what phones trust.`);
  process.exit(1);
}

const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 4096 });
const key = forge.pki.privateKeyFromPem(privateKey.export({ type: 'pkcs1', format: 'pem' }));
const pub = forge.pki.setRsaPublicKey(key.n, key.e);

const cert = forge.pki.createCertificate();
cert.publicKey = pub;
cert.serialNumber = '01' + randomBytes(8).toString('hex');
cert.validity.notBefore = new Date();
cert.validity.notAfter = new Date();
cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 30);
const dn = [{ name: 'commonName', value: 'Appbutik' }, { name: 'organizationName', value: 'Appbutik' }];
cert.setSubject(dn);
cert.setIssuer(dn);
cert.sign(key, forge.md.sha256.create());

// Java's PKCS12 support expects the key password to equal the store password.
const password = randomBytes(24).toString('base64url');
const p12 = forge.pkcs12.toPkcs12Asn1(key, [cert], password, {
  algorithm: '3des',
  friendlyName: alias,
  generateLocalKeyId: true,
});
const p12Der = Buffer.from(forge.asn1.toDer(p12).getBytes(), 'binary');

const certDer = Buffer.from(forge.asn1.toDer(forge.pki.certificateToAsn1(cert)).getBytes(), 'binary');
const fingerprint = createHash('sha256').update(certDer).digest('hex');

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'keystore.p12'), p12Der);
writeFileSync(join(outDir, 'keystore.b64'), p12Der.toString('base64'));
writeFileSync(join(outDir, 'secrets.env'), `FDROID_KEYSTORE_PASS=${password}\nFDROID_KEY_ALIAS=${alias}\n`);
writeFileSync(join(outDir, 'fingerprint.txt'), fingerprint + '\n');

console.log(`Keystore written to ${outDir}`);
console.log(`Alias: ${alias}`);
console.log(`Repo fingerprint (SHA-256): ${fingerprint}`);
