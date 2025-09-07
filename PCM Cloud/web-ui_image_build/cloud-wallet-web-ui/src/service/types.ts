import { type GenericObjectType } from '@rjsf/utils';
import type { JSONSchema7 } from 'json-schema';

export interface DidData {
  list: Did[];
}

export interface Did {
  id: string;
  did: string;
  timestamp: string;
}

export interface DevicesData {
  added: string;
  eventType: string;
  group: string;
  protocol: string;
  remoteDid: string;
  routingKey: string;
  topic: string;
  recipientDid: [string];
  properties: {
    account: string;
    greeting: string;
  };
}

export interface PluginsData {
  id: string;
  name: string;
  uploaded: string;
  issuer: string;
}

export interface BackupList {
  backups: BackupData[];
}

export interface BackupData {
  bindingId: string;
  name: string;
  timestamp: string;
  credentials: string;
  user_id: string;
}

export interface BackupUpload {
  expiresInSeconds: number;
  path: string;
}

export interface HistoryData {
  events: Events[];
}

export interface Events {
  event: string;
  timestamp: string;
  type: string;
  userId: string;
}

export interface IssuanceSchemaData {
  id: string;
  name: string;
}

export interface BackupQrCodeData {
  expiresInSeconds: number;
  path: string;
}

export type Format = Record<
  string,
  {
    proof_type?: string[];
  }
>;

export interface CredentialsData {
  id: string;
  credential: string;
}

export interface KeycloakConfig {
  baseUrl: string;
  realm: string;
  clientId: string;
  auth: string;
}

export interface KeycloakAndMetadata {
  keycloakConfig: KeycloakConfig;
  metadata: OidcMetadata;
}

export interface OidcMetadata {
  issuer: string;
  authorization_endpoint: string;
  token_endpoint: string;
  token_endpoint_auth_methods_supported: string[];
  token_endpoint_auth_signing_alg_values_supported: string[];
  userinfo_endpoint: string;
  check_session_iframe: string;
  end_session_endpoint: string;
  jwks_uri: string;
  registration_endpoint: string;
  scopes_supported: string[];
  response_types_supported: string[];
  acr_values_supported: string[];
  subject_types_supported: string[];
  request_object_signing_alg_values_supported: string[];
  display_values_supported: string[];
  claim_types_supported: string[];
  claims_supported: string[];
  claims_parameter_supported: boolean;
  service_documentation: string;
  ui_locales_supported: string[];
  revocation_endpoint: string;
  introspection_endpoint: string;
  frontchannel_logout_supported: boolean;
  frontchannel_logout_session_supported: boolean;
  backchannel_logout_supported: boolean;
  backchannel_logout_session_supported: boolean;
  grant_types_supported: string[];
  response_modes_supported: string[];
  code_challenge_methods_supported: string[];
}

export type CredentialSubject = Record<string, string | DetailedSubject>;

export interface Proof {
  type: string;
  created: string;
  challenge?: string;
  domain?: string;
  jws: string;
  proofPurpose: string;
  verificationMethod: string;
}

export interface CredentialData {
  '@context'?: Array<string | object>;
  id?: string;
  holder?: string;
  type?: string | string[];
  Type?: string[];
  vct: string;
  issuer?: string;
  issuanceDate?: string;
  credentialSubject?: CredentialSubject;
  proof?: Proof;
}

export interface JWT {
  header: JWTHeader;
  payload: JWTPayload;
  signature: string;
}

export interface JWTHeader {
  alg: string;
  kid: string;
  typ: string;
}

export interface JWTPayload {
  cnf: {
    jwk: JWK;
  };
  iat?: number;
  iss?: string;
  vct: string;
  _sd_alg: string;
  [key: string]: any;
}

export interface JWK {
  alg?: string;
  crv?: string;
  kid?: string;
  kty?: string;
  x?: string;
}

export interface Credential {
  data: string;
  type: string;
}

export type ValidCredential = Credential & ({ type: string | string[] } | { Type: string } | { vct: string });

export interface CredentialInPresentation {
  '@context': string[];
  id?: string;
  holder?: string;
  type: string[];
  issuer?: string;
  issuanceDate?: string;
  proof?: Proof;
  verifiableCredential: CredentialData[];
}

export interface Description {
  id: string;
  name?: string;
  purpose?: string;
  format?: string;
}

export interface CredentialOffer {
  credential_offer: string;
}

export type DetailedSubject = Record<
  string,
  {
    name: string;
    type: string;
  }
>;

export type CodedCredentialList = Record<string, Credential>;

export type CredentialList = Record<string, CredentialData>;

export type CredentialPresentationList = Record<string, CredentialInPresentation>;

export interface VerifiableCredentials {
  description: Description;
  credentials: CredentialList;
}

export interface CodedVerifiableCredentials {
  description: Description;
  credentials: CodedCredentialList;
}

export interface VerifiablePresentation {
  description: Description;
  credentials: CredentialPresentationList;
}

export interface DefaultConfig {
  historyLimit: number;
  language: string;
}

export interface SchemaData {
  data: SchemaDataWithId;
  ui: GenericObjectType;
}

export interface SchemaDataWithId extends JSONSchema7 {
  $id: string;
  $schema: string;
}

export interface OfferingData {
  groupId: string;
  requestId: string;
  metadata: Metadata;
  offering: Offering;
  status: string;
  timestamp: string;
}

export interface Metadata {
  credential_issuer: string;
  authorization_servers: string[];
  credential_endpoint: string;
  batch_credential_endpoint: any;
  notification_endpoint: any;
  signed_metadata: any;
  credential_identifiers_supported: boolean;
  deferred_credential_endpoint: any;
  credential_response_encryption: CredentialResponseEncryption;
  display: any;
  credential_configurations_supported: CredentialConfigurationsSupported;
}

export interface CredentialResponseEncryption {
  alg_values_supported: any;
  enc_values_supported: any;
  encryption_required: boolean;
}

export type CredentialConfigurationsSupported = Record<string, CredentialConfiguration>;

export interface CredentialConfiguration {
  format: string;
  scope: string;
  cryptographic_binding_methods_supported: string[];
  credential_signing_alg_values_supported: string[];
  credential_definition: CredentialDefinition;
  proof_types_supported: ProofTypesSupported;
  display: DetailedDisplay[];
}

export interface Offering {
  credential_issuer: string;
  credential_configuration_ids: string[];
  grants: Grants;
}

export interface Grants {
  authorization_code: AuthorizationCode;
  'urn:ietf:params:oauth:grant-type:pre-authorized_code': UrnIetfParamsOauthGrantTypePreAuthorizedCode;
}

export interface AuthorizationCode {
  issuer_state: string;
}

export interface UrnIetfParamsOauthGrantTypePreAuthorizedCode {
  'pre-authorized_code': string;
  tx_code: TxCode;
  interval: number;
}

export interface TxCode {
  input_mode: string;
  length: number;
  description: string;
}

export type IssuanceData = Record<string, Issuance>;

export interface Issuance {
  format: string;
  scope: string;
  cryptographic_binding_methods_supported: string[];
  credential_signing_alg_values_supported: string[];
  credential_definition: CredentialDefinition;
  proof_types_supported: ProofTypesSupported;
  display: DetailedDisplay[];
  topic: string;
  schema: SchemaData;
}

export interface CredentialDefinition {
  type: string[];
  credentialSubject: CredentialSubjectOffering;
}

export type CredentialSubjectOffering = Record<string, Display>;

export interface Display {
  display?:
    | Array<{
        name: string;
        locale?: string;
      }>
    | {
        name: string;
        locale?: string;
      };
}

export interface DetailedDisplay {
  name: string;
  locale: string;
  logo: Logo;
  background_color: string;
  text_color: string;
}

export interface Logo {
  url: string;
  alternative_text: string;
}

export type ProofTypesSupported = Record<
  string,
  {
    proof_signing_alg_values_supported: string[];
  }
>;

export interface Constraints {
  limitDisclosure?: Disclosure;
  fields?: Field[];
}

export type Disclosure = 'required' | 'preferred';

export interface Field {
  path: string[];
  id?: string;
  purpose?: string;
  filter?: Filter;
  name?: string;
}

export interface Filter {
  type: string;
  pattern: string;
}

export interface InputDescriptor {
  id: string;
  format: Format;
  constraints: Constraints;
  group?: string[];
}

export interface PresentationDefinitionData {
  id: string;
  name: string;
  purpose: string;
  input_descriptors: InputDescriptor[] | null;
  format?: Format;
}

export interface PluginDetails {
  id: string;
  name: string;
  description: string;
}
