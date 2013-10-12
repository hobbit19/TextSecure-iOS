//
//  Cryptography.m
//  TextSecureiOS
//
//  Created by Christine Corbett Moran on 3/26/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "Cryptography.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonHMAC.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h>
#include <CommonCrypto/CommonHMAC.h>

#import "NSData+Conversion.h"
#import "KeychainWrapper.h"
#import "Constants.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#include "NSString+Conversion.h"
#include "NSData+Base64.h"
#include "ECKeyPair.h"
#import "CryptographyDatabase.h"

@implementation Cryptography


+(NSString*) generateNewAccountAuthenticationToken {
  NSMutableData* authToken = [Cryptography generateRandomBytes:16];
  NSString* authTokenPrint = [[NSData dataWithData:authToken] hexadecimalString];
  return authTokenPrint;
}

+(NSString*) generateNewSignalingKeyToken {
   /*The signalingKey is 32 bytes of AES material (256bit AES) and 20 bytes of Hmac key material (HmacSHA1) concatenated into a 52 byte slug that is base64 encoded. */
  NSMutableData* signalingKeyToken = [Cryptography generateRandomBytes:52];
  NSString* signalingKeyTokenPrint = [[NSData dataWithData:signalingKeyToken] base64EncodedString];
  return signalingKeyTokenPrint;

}


+(NSMutableData*) generateRandomBytes:(int)numberBytes {
  NSMutableData* randomBytes = [NSMutableData dataWithLength:numberBytes];
  int err = 0;
  err = SecRandomCopyBytes(kSecRandomDefault,numberBytes,[randomBytes mutableBytes]);
  if(err != noErr) {
    @throw [NSException exceptionWithName:@"random problem" reason:@"problem generating the random " userInfo:nil];
  }
  return randomBytes;
}

+(void) generateAndStoreIdentityKey {
  /* 
   An identity key is an ECC key pair that you generate at install time. It never changes, and is used to certify your identity (clients remember it whenever they see it communicated from other clients and ensure that it's always the same).
   
   In secure protocols, identity keys generally never actually encrypt anything, so it doesn't affect previous confidentiality if they are compromised. The typical relationship is that you have a long term identity key pair which is used to sign ephemeral keys (like the prekeys).
   */
  ECKeyPair *identityKey = [[ECKeyPair alloc] init];
  #ifdef DEBUG
  NSLog(@"testing private key %@",[identityKey getSerializedPrivateKey]);
  NSLog(@"testing public key %@",[identityKey getSerializedPublicKey]);
  #endif
  CryptographyDatabase *cryptoDB = [[CryptographyDatabase alloc] init];
  [cryptoDB storeIdentityKey:identityKey];
  [cryptoDB getIdentityKey];
}

+ (NSString*) getMasterSecretyKey {
  /*
   this is an AES256 key , encrypted using pbkdf2 of user's password
   user's password is given and is specific to textsecure
   */
  // TODO: actually implement this
  return @"hello world";
}
+(void) generateAndStoreNewPreKeys:(int)numberOfPreKeys{
  @throw [NSException exceptionWithName:@"not implemented" reason:@"because we need to" userInfo:nil];
  //  // TODO: Check if there is an old counter, if so, keep up where you left off
  //  //NSString* prekeyCounter = [Cryptography getPrekeyCounter];
  //  NSInteger *baseInt = arc4random() % 16777216; //16777216 is 0xFFFFFF
  //  NSString *hex = [NSString stringWithFormat:@"%06X", baseInt];
  //
  //  for (int i=0; i<numberOfPreKeys; i++) {
  //    // Generate a new prekey here
  //
  //  }
  //
  //  [Cryptography storePrekeyCounter:hex];
  
}




+ (BOOL) storePrekeyCounter:(NSString*)token {
  return [KeychainWrapper createKeychainValue:token forIdentifier:prekeyCounterStorageId];
}


+ (NSString*) getPrekeyCounter {
  return [KeychainWrapper keychainStringFromMatchingIdentifier:prekeyCounterStorageId];
}


#pragma mark Authentication Token

+ (BOOL) storeAuthenticationToken:(NSString*)token {
  return [KeychainWrapper createKeychainValue:token forIdentifier:authenticationTokenStorageId];
}


+ (NSString*) getAuthenticationToken {
  return [KeychainWrapper keychainStringFromMatchingIdentifier:authenticationTokenStorageId];
}

#pragma mark Username (Phone number)

+ (BOOL) storeUsernameToken:(NSString*)token {
  return [KeychainWrapper createKeychainValue:token forIdentifier:usernameTokenStorageId];
}

+ (NSString*) getUsernameToken {
  return [KeychainWrapper keychainStringFromMatchingIdentifier:usernameTokenStorageId];
}

#pragma mark Authorization Token

+ (NSString*) getAuthorizationToken {
    return [self getAuthorizationTokenFromAuthToken:[Cryptography getAuthenticationToken]];
}

+ (NSString*) getAuthorizationTokenFromAuthToken:(NSString*)authToken{
    NSLog(@"Username : %@ and AuthToken: %@", [Cryptography getUsernameToken], [Cryptography getAuthenticationToken] );
    return [NSString stringWithFormat:@"%@:%@",[Cryptography getUsernameToken],[Cryptography getAuthenticationToken]];
}

#pragma mark SignalingKey

+ (BOOL) storeSignalingKeyToken:(NSString*)token {
    return [KeychainWrapper createKeychainValue:token forIdentifier:signalingTokenStorageId];
}

+ (NSString*) getSignalingKeyToken {
  return [KeychainWrapper keychainStringFromMatchingIdentifier:signalingTokenStorageId];
}


+ (NSData*)computeMACDigestForString:(NSString*)input withSeed:(NSString*)seed {
  //  void CCHmac(CCHmacAlgorithm algorithm, const void *key, size_t keyLength, const void *data,
  //       size_t dataLength, void *macOut);
  const char *cInput = [input UTF8String];
  const char *cSeed = [seed UTF8String];
  unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
  CCHmac(kCCHmacAlgSHA1, cSeed, strlen(cSeed), cInput,strlen(cInput),cHMAC);
  NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
  return HMAC;
  
}
+ (NSString*)computeSHA1DigestForString:(NSString*)input {
  // Here we are taking in our string hash, placing that inside of a C Char Array, then parsing it through the SHA1 encryption method.
  const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
  NSData *data = [NSData dataWithBytes:cstr length:input.length];
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  
  CC_SHA1(data.bytes, data.length, digest);
  
  NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
  
  for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
    [output appendFormat:@"%02x", digest[i]];
  }
  
  return output;
}






@end
