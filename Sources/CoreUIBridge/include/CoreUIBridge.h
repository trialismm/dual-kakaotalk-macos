#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const CoreUIBridgeErrorDomain;

typedef NS_ERROR_ENUM(CoreUIBridgeErrorDomain, CoreUIBridgeError) {
    CoreUIBridgeErrorFrameworkUnavailable = 1,
    CoreUIBridgeErrorSelectorUnavailable,
    CoreUIBridgeErrorCatalogOpenFailed,
    CoreUIBridgeErrorRenditionNotFound,
    CoreUIBridgeErrorInvalidBitmap,
    CoreUIBridgeErrorMutationUnsupported,
    CoreUIBridgeErrorWriteFailed,
};

/// Each result contains name, scale, width, height, and hasInternalLink.
FOUNDATION_EXPORT BOOL CoreUIBridgeCopyNamedImageRenditions(
    NSURL *catalogURL,
    NSArray<NSDictionary<NSString *, id> *> * _Nullable * _Nullable renditions,
    NSError * _Nullable * _Nullable error);

/// Replaces one named bitmap rendition in an already-copied catalog. rgbaBytes is premultiplied RGBA8.
FOUNDATION_EXPORT BOOL CoreUIBridgeReplaceNamedImageRendition(
    NSURL *catalogURL,
    NSString *name,
    NSInteger scale,
    NSInteger width,
    NSInteger height,
    NSData *rgbaBytes,
    NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
