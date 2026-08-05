#import "CoreUIBridge.h"
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

NSErrorDomain const CoreUIBridgeErrorDomain = @"CoreUIBridgeErrorDomain";

// Declarations below are derived from MIT-licensed cartools CoreUI headers.
@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)allImageNames;
- (id)imageWithName:(NSString *)name scaleFactor:(double)scale;
- (id)_themeStore;
@end

@interface CUINamedImage : NSObject
@property(nonatomic, readonly) CGSize size;
@property(nonatomic, readonly) double scale;
- (id)rendition;
@end

@interface CUIThemeRendition : NSObject
- (instancetype)initWithCSIData:(NSData *)data forKey:(const void *)key;
@end

static BOOL CUIBridgeFail(CoreUIBridgeError code, NSString *description, NSError **error) {
    if (error != NULL) {
        *error = [NSError errorWithDomain:CoreUIBridgeErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return NO;
}
static CGRect CUIBridgeSendCGRect(id object, SEL selector) {
#if defined(__x86_64__)
    CGRect value = CGRectZero;
    ((void (*)(CGRect *, id, SEL))objc_msgSend_stret)(&value, object, selector);
    return value;
#else
    return ((CGRect (*)(id, SEL))objc_msgSend)(object, selector);
#endif
}

static Class CUIBridgeClass(NSString *name, NSError **error) {
    Class cls = NSClassFromString(name);
    if (cls == Nil) {
        CUIBridgeFail(CoreUIBridgeErrorFrameworkUnavailable, [NSString stringWithFormat:@"CoreUI class %@ is unavailable", name], error);
    }
    return cls;
}

static id CUIBridgeCatalog(NSURL *url, NSError **error) {
    NSError *fileError = nil;
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:url error:&fileError];
    if (handle == nil) {
        CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, fileError.localizedDescription ?: @"Unable to read asset catalog", error);
        return nil;
    }
    NSData *header = [handle readDataOfLength:8];
    [handle closeFile];
    const char expected[] = "BOMStore";
    if (header.length != 8 || memcmp(header.bytes, expected, 8) != 0) {
        CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, @"File is not a compiled asset catalog", error);
        return nil;
    }

    Class catalogClass = CUIBridgeClass(@"CUICatalog", error);
    if (catalogClass == Nil) return nil;
    SEL selector = @selector(initWithURL:error:);
    if (![catalogClass instancesRespondToSelector:selector]) {
        CUIBridgeFail(CoreUIBridgeErrorSelectorUnavailable, @"CUICatalog does not support initWithURL:error:", error);
        return nil;
    }
    @try {
        NSError *openError = nil;
        id catalog = ((id (*)(id, SEL, NSURL *, NSError **))objc_msgSend)([catalogClass alloc], selector, url, &openError);
        if (catalog == nil) {
            CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, openError.localizedDescription ?: @"Unable to open asset catalog", error);
        }
        return catalog;
    } @catch (NSException *exception) {
        CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, exception.reason ?: @"CoreUI rejected the asset catalog", error);
        return nil;
    }
}

static NSData *CUIBridgeRGBAData(CGImageRef image) {
    if (image == NULL) return nil;
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        data.mutableBytes, width, height, 8, width * 4, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault
    );
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    return data;
}

BOOL CoreUIBridgeCopyNamedImageRenditions(NSURL *catalogURL, NSArray<NSDictionary<NSString *,id> *> **renditions, NSError **error) {
    if (!catalogURL.isFileURL) return CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, @"Catalog URL must be a file URL", error);
    id catalog = CUIBridgeCatalog(catalogURL, error);
    if (catalog == nil) return NO;

    @try {
        SEL structuredSelector = NSSelectorFromString(@"_themeStore");
        if (![catalog respondsToSelector:structuredSelector]) {
            return CUIBridgeFail(CoreUIBridgeErrorSelectorUnavailable, @"CoreUI structured theme store is unavailable", error);
        }
        id structuredStore = ((id (*)(id, SEL))objc_msgSend)(catalog, structuredSelector);
        SEL assetStoreSelector = NSSelectorFromString(@"themeStore");
        SEL nameSelector = NSSelectorFromString(@"renditionNameForKeyList:");
        SEL renditionSelector = NSSelectorFromString(@"renditionWithKey:");
        if (structuredStore == nil ||
            ![structuredStore respondsToSelector:assetStoreSelector] ||
            ![structuredStore respondsToSelector:nameSelector] ||
            ![structuredStore respondsToSelector:renditionSelector]) {
            return CUIBridgeFail(CoreUIBridgeErrorSelectorUnavailable, @"CoreUI rendition enumeration selectors are unavailable", error);
        }
        id assetStore = ((id (*)(id, SEL))objc_msgSend)(structuredStore, assetStoreSelector);
        SEL keysSelector = NSSelectorFromString(@"allAssetKeys");
        if (assetStore == nil || ![assetStore respondsToSelector:keysSelector]) {
            return CUIBridgeFail(CoreUIBridgeErrorSelectorUnavailable, @"CoreUI asset keys are unavailable", error);
        }
        NSArray *keys = ((id (*)(id, SEL))objc_msgSend)(assetStore, keysSelector);
        if (![keys isKindOfClass:NSArray.class]) {
            return CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, @"CoreUI returned invalid asset keys", error);
        }

        NSMutableArray *result = [NSMutableArray arrayWithCapacity:keys.count];
        SEL keyListSelector = NSSelectorFromString(@"keyList");
        SEL scaleSelector = NSSelectorFromString(@"scale");
        SEL linkSelector = NSSelectorFromString(@"isInternalLink");
        SEL imageSelector = NSSelectorFromString(@"uncroppedImage");
        for (id key in keys) {
            if (![key respondsToSelector:keyListSelector]) continue;
            const void *keyList = ((const void *(*)(id, SEL))objc_msgSend)(key, keyListSelector);
            if (keyList == NULL) continue;
            NSString *name = ((id (*)(id, SEL, const void *))objc_msgSend)(structuredStore, nameSelector, keyList);
            id rendition = ((id (*)(id, SEL, const void *))objc_msgSend)(structuredStore, renditionSelector, keyList);
            if (![name isKindOfClass:NSString.class] || rendition == nil || ![rendition respondsToSelector:imageSelector]) continue;
            CGImageRef cgImage = ((CGImageRef (*)(id, SEL))objc_msgSend)(rendition, imageSelector);
            NSData *rgbaData = CUIBridgeRGBAData(cgImage);
            if (rgbaData == nil) continue;
            double scale = [rendition respondsToSelector:scaleSelector]
                ? ((double (*)(id, SEL))objc_msgSend)(rendition, scaleSelector)
                : 0;
            BOOL hasInternalLink = [rendition respondsToSelector:linkSelector]
                ? ((BOOL (*)(id, SEL))objc_msgSend)(rendition, linkSelector)
                : NO;
            [result addObject:@{
                @"name": name,
                @"scale": @(llround(scale)),
                @"width": @(CGImageGetWidth(cgImage)),
                @"height": @(CGImageGetHeight(cgImage)),
                @"hasInternalLink": @(hasInternalLink),
                @"rgbaData": rgbaData
            }];
        }
        if (renditions != NULL) *renditions = result.copy;
        return YES;
    } @catch (NSException *exception) {
        return CUIBridgeFail(CoreUIBridgeErrorCatalogOpenFailed, exception.reason ?: @"CoreUI enumeration failed", error);
    }
}

static void CUIBridgeSetObject(id object, NSString *selectorName, id value) {
    SEL selector = NSSelectorFromString(selectorName);
    if ([object respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(object, selector, value);
    }
}

static void CUIBridgeSetInteger(id object, NSString *selectorName, long long value) {
    SEL selector = NSSelectorFromString(selectorName);
    if ([object respondsToSelector:selector]) {
        ((void (*)(id, SEL, long long))objc_msgSend)(object, selector, value);
    }
}

static void CUIBridgeSetDouble(id object, NSString *selectorName, double value) {
    SEL selector = NSSelectorFromString(selectorName);
    if ([object respondsToSelector:selector]) {
        ((void (*)(id, SEL, double))objc_msgSend)(object, selector, value);
    }
}

BOOL CoreUIBridgeReplaceNamedImageRendition(NSURL *catalogURL, NSString *name, NSInteger scale, NSInteger width, NSInteger height, NSData *rgbaBytes, NSError **error) {
    if (!catalogURL.isFileURL || name.length == 0 || scale < 1 || width < 1 || height < 1 ||
        rgbaBytes.length != (NSUInteger)(width * height * 4)) {
        return CUIBridgeFail(CoreUIBridgeErrorInvalidBitmap, @"Invalid replacement bitmap", error);
    }

    id catalog = CUIBridgeCatalog(catalogURL, error);
    if (catalog == nil) return NO;

    @try {
        id structuredStore = ((id (*)(id, SEL))objc_msgSend)(catalog, NSSelectorFromString(@"_themeStore"));
        id assetStore = ((id (*)(id, SEL))objc_msgSend)(structuredStore, NSSelectorFromString(@"themeStore"));
        NSArray *keys = ((id (*)(id, SEL))objc_msgSend)(assetStore, NSSelectorFromString(@"allAssetKeys"));
        SEL keyListSelector = NSSelectorFromString(@"keyList");
        SEL nameSelector = NSSelectorFromString(@"renditionNameForKeyList:");
        SEL renditionSelector = NSSelectorFromString(@"renditionWithKey:");

        id existing = nil;
        const void *existingKeyList = NULL;
        for (id key in keys) {
            if (![key respondsToSelector:keyListSelector]) continue;
            const void *keyList = ((const void *(*)(id, SEL))objc_msgSend)(key, keyListSelector);
            NSString *candidateName = ((id (*)(id, SEL, const void *))objc_msgSend)(structuredStore, nameSelector, keyList);
            id candidate = ((id (*)(id, SEL, const void *))objc_msgSend)(structuredStore, renditionSelector, keyList);
            double candidateScale = [candidate respondsToSelector:NSSelectorFromString(@"scale")]
                ? ((double (*)(id, SEL))objc_msgSend)(candidate, NSSelectorFromString(@"scale"))
                : 0;
            if ([candidateName isEqualToString:name] && llround(candidateScale) == scale) {
                existing = candidate;
                existingKeyList = keyList;
                break;
            }
        }
        if (existing == nil || existingKeyList == NULL) {
            return CUIBridgeFail(CoreUIBridgeErrorRenditionNotFound, @"Named rendition was not found", error);
        }

        BOOL internalLink = [existing respondsToSelector:NSSelectorFromString(@"isInternalLink")] &&
            ((BOOL (*)(id, SEL))objc_msgSend)(existing, NSSelectorFromString(@"isInternalLink"));
        id target = existing;
        if (internalLink && [existing respondsToSelector:NSSelectorFromString(@"linkingToRendition")]) {
            target = ((id (*)(id, SEL))objc_msgSend)(existing, NSSelectorFromString(@"linkingToRendition"));
        }
        if (target == nil) {
            return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"Linked rendition target is unavailable", error);
        }

        SEL renditionKeySelector = NSSelectorFromString(@"keyList");
        const void *targetKeyList = [target respondsToSelector:renditionKeySelector]
            ? ((const void *(*)(id, SEL))objc_msgSend)(target, renditionKeySelector)
            : existingKeyList;
        SEL keyDataSelector = NSSelectorFromString(@"convertRenditionKeyToKeyData:");
        if (![structuredStore respondsToSelector:keyDataSelector]) {
            return CUIBridgeFail(CoreUIBridgeErrorSelectorUnavailable, @"CoreUI key conversion is unavailable", error);
        }
        NSData *carKey = ((id (*)(id, SEL, const void *))objc_msgSend)(structuredStore, keyDataSelector, targetKeyList);
        if (carKey == nil) {
            return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"CoreUI could not encode the rendition key", error);
        }
        if (internalLink) {
            NSData *csiData = ((id (*)(id, SEL, id))objc_msgSend)(assetStore, NSSelectorFromString(@"assetForKey:"), carKey);
            Class renditionClass = CUIBridgeClass(@"CUIThemeRendition", error);
            if (csiData == nil || renditionClass == Nil) {
                return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"Linked atlas data is unavailable", error);
            }

            // Tahoe removed initWithCSIData:forKey:. The linked target returned by
            // CoreUI already carries the atlas image and metadata, so use it when
            // the legacy reconstruction initializer is unavailable.
            SEL initializer = NSSelectorFromString(@"initWithCSIData:forKey:");
            if ([renditionClass instancesRespondToSelector:initializer]) {
                CUIThemeRendition *reconstructed = [[renditionClass alloc] initWithCSIData:csiData forKey:targetKeyList];
                if (reconstructed == nil) {
                    return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"Linked atlas rendition is invalid", error);
                }
                target = reconstructed;
            }
        }

        CGImageRef linkedAtlasImage = NULL;
        if (internalLink) {
            SEL imageSelector = [target respondsToSelector:NSSelectorFromString(@"unslicedImage")]
                ? NSSelectorFromString(@"unslicedImage")
                : ([target respondsToSelector:NSSelectorFromString(@"uncroppedImage")]
                    ? NSSelectorFromString(@"uncroppedImage")
                    : NULL);
            if (imageSelector == NULL) {
                return CUIBridgeFail(CoreUIBridgeErrorSelectorUnavailable, @"CoreUI linked atlas image selector is unavailable", error);
            }
            linkedAtlasImage = ((CGImageRef (*)(id, SEL))objc_msgSend)(target, imageSelector);
            if (linkedAtlasImage == NULL) {
                return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"Linked atlas image is unavailable", error);
            }
        }

        CGSize canvasSize = [target respondsToSelector:NSSelectorFromString(@"unslicedSize")]
            ? ((CGSize (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"unslicedSize"))
            : (linkedAtlasImage != NULL
                ? CGSizeMake(CGImageGetWidth(linkedAtlasImage), CGImageGetHeight(linkedAtlasImage))
                : CGSizeMake(width, height));
        CGRect destination = [existing respondsToSelector:NSSelectorFromString(@"_destinationFrame")]
            ? CUIBridgeSendCGRect(existing, NSSelectorFromString(@"_destinationFrame"))
            : CGRectMake(0, 0, width, height);
        CGRect targetSlice = [target respondsToSelector:NSSelectorFromString(@"_destinationFrame")]
            ? CUIBridgeSendCGRect(target, NSSelectorFromString(@"_destinationFrame"))
            : CGRectMake(0, 0, canvasSize.width, canvasSize.height);
        CGRect canvasBounds = CGRectMake(0, 0, canvasSize.width, canvasSize.height);
        if (canvasSize.width < 1 || canvasSize.height < 1 ||
            (internalLink && !CGRectContainsRect(canvasBounds, destination))) {
            return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"Linked atlas geometry is invalid", error);
        }

        Class mutableClass = CUIBridgeClass(@"CUIMutableCommonAssetStorage", error);
        Class generatorClass = CUIBridgeClass(@"CSIGenerator", error);
        Class bitmapClass = CUIBridgeClass(@"CSIBitmapWrapper", error);
        if (mutableClass == Nil || generatorClass == Nil || bitmapClass == Nil) return NO;

        id mutableStore = ((id (*)(id, SEL, id, BOOL))objc_msgSend)(
            [mutableClass alloc], NSSelectorFromString(@"initWithPath:forWriting:"), catalogURL.path, YES
        );
        id bitmap = ((id (*)(id, SEL, NSUInteger, NSUInteger))objc_msgSend)(
            [bitmapClass alloc], NSSelectorFromString(@"initWithPixelWidth:pixelHeight:"),
            (NSUInteger)llround(canvasSize.width), (NSUInteger)llround(canvasSize.height)
        );
        void *contextPointer = ((void *(*)(id, SEL))objc_msgSend)(bitmap, NSSelectorFromString(@"bitmapContext"));
        CGContextRef context = (CGContextRef)contextPointer;
        if (mutableStore == nil || bitmap == nil || context == NULL) {
            return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"CoreUI mutable bitmap storage is unavailable", error);
        }

        if (internalLink) {
            CGContextDrawImage(context, canvasBounds, linkedAtlasImage);
            CGContextClearRect(context, destination);
        }

        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)rgbaBytes);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef replacement = CGImageCreate(
            width, height, 8, 32, width * 4, colorSpace,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault,
            provider, NULL, false, kCGRenderingIntentDefault
        );
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        if (replacement == NULL) {
            return CUIBridgeFail(CoreUIBridgeErrorInvalidBitmap, @"Unable to create replacement image", error);
        }
        CGContextDrawImage(context, internalLink ? destination : CGRectMake(0, 0, canvasSize.width, canvasSize.height), replacement);
        CGImageRelease(replacement);

        long long type = [target respondsToSelector:NSSelectorFromString(@"type")]
            ? ((long long (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"type"))
            : 0;
        long long subtype = [target respondsToSelector:NSSelectorFromString(@"subtype")]
            ? ((long long (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"subtype"))
            : 0;
        short layout = (short)(type == 0 ? subtype : type);
        id generator = ((id (*)(id, SEL, CGSize, NSUInteger, short))objc_msgSend)(
            [generatorClass alloc], NSSelectorFromString(@"initWithCanvasSize:sliceCount:layout:"),
            canvasSize, 1, layout
        );
        if (generator == nil) {
            return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"CoreUI generator is unavailable", error);
        }

        CUIBridgeSetObject(generator, @"setName:", [target respondsToSelector:NSSelectorFromString(@"name")]
            ? ((id (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"name")) : name);
        CUIBridgeSetDouble(generator, @"setOpacity:", [target respondsToSelector:NSSelectorFromString(@"opacity")]
            ? ((double (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"opacity")) : 1.0);
        CUIBridgeSetInteger(generator, @"setScaleFactor:", [target respondsToSelector:NSSelectorFromString(@"scale")]
            ? llround(((double (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"scale"))) : scale);
        CUIBridgeSetInteger(generator, @"setTemplateRenderingMode:", [target respondsToSelector:NSSelectorFromString(@"templateRenderingMode")]
            ? ((long long (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(@"templateRenderingMode")) : 0);
        ((void (*)(id, SEL, id))objc_msgSend)(generator, NSSelectorFromString(@"addBitmap:"), bitmap);
        ((void (*)(id, SEL, CGRect))objc_msgSend)(generator, NSSelectorFromString(@"addSliceRect:"), targetSlice);
        NSData *csi = ((id (*)(id, SEL, BOOL))objc_msgSend)(generator, NSSelectorFromString(@"CSIRepresentationWithCompression:"), YES);
        if (csi == nil) {
            return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, @"CoreUI did not generate rendition data", error);
        }

        BOOL set = ((BOOL (*)(id, SEL, id, id))objc_msgSend)(mutableStore, NSSelectorFromString(@"setAsset:forKey:"), csi, carKey);
        BOOL wrote = set && ((BOOL (*)(id, SEL, BOOL))objc_msgSend)(mutableStore, NSSelectorFromString(@"writeToDiskAndCompact:"), YES);
        return wrote ? YES : CUIBridgeFail(CoreUIBridgeErrorWriteFailed, @"CoreUI did not write the catalog", error);
    } @catch (NSException *exception) {
        return CUIBridgeFail(CoreUIBridgeErrorMutationUnsupported, exception.reason ?: @"CoreUI mutation failed", error);
    }
}
