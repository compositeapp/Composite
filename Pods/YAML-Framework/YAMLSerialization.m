//
//  YAMLSerialization.m
//  YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//    Released under MIT License
//
//  Copyright 2010 Mirek Rusin
//  Copyright 2010 Stanislav Yudin
//

#import "YAMLSerialization.h"
#import "yaml.h"

NSString *const YAMLErrorDomain = @"com.github.mirek.yaml";

// Assumes NSError **error is in the current scope
#define YAML_SET_ERROR(errorCode, description, recovery) \
  if (error) \
    *error = [NSError errorWithDomain: YAMLErrorDomain \
                                 code: errorCode \
                             userInfo: [NSDictionary dictionaryWithObjectsAndKeys: \
                                        description, NSLocalizedDescriptionKey, \
                                        recovery, NSLocalizedRecoverySuggestionErrorKey, \
                                        nil]]

@implementation YAMLSerialization

static NSNumber *ParseBoolean(NSString *str) {
    for (NSString *s in @[@"y", @"yes", @"true", @"on"])
        if ([s isEqualToString:str.lowercaseString])
            return @YES;
    for (NSString *s in @[@"n", @"no", @"false", @"off"])
        if ([s isEqualToString:str.lowercaseString])
            return @NO;
    return nil;
}

static NSNumber *ParseNumber(NSString *str) {
    static dispatch_once_t numberFormatterOnceToken;
    static NSNumberFormatter *numberFormatter = nil;
    dispatch_once(&numberFormatterOnceToken, ^{
        numberFormatter = [[NSNumberFormatter alloc] init];
    });
    return [[numberFormatter numberFromString:str] retain];
}

static NSDate *ParseDate(NSString *str) {
    static dispatch_once_t dateFormatterOnceToken;
    static NSDateFormatter *dateFormatter = nil;
    dispatch_once(&dateFormatterOnceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        // set dateformatter defaults (otherwise it picks up current settings)
        dateFormatter.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatter.dateFormat = @"yyyy-MM-dd";
    });
    return [[dateFormatter dateFromString:str] retain];
}

static NSNull *ParseNull(NSString *str) {
    if (str.length == 0 || [str isEqualToString:@"~"] || [str.lowercaseString isEqualToString:@"null"])
        return [NSNull null];
    return nil;
}

#pragma mark Reading YAML

static int
__YAMLSerializationParserInputReadHandler (void *data, unsigned char *buffer, size_t size, size_t *size_read) {
    NSInteger outcome = [(NSInputStream *) data read: (uint8_t *) buffer maxLength: size];
  if (outcome < 0) {
    *size_read = 0;
    return NO;
  } else {
    *size_read = outcome;
    return YES;
  }
}

// Serialize single, parsed document. Does not destroy the document.
static id
__YAMLSerializationObjectWithYAMLDocument (yaml_document_t *document, YAMLReadOptions opt, NSError **error) {

    id root = nil;
    id *objects = nil;

    // Mutability options
    Class arrayClass = [NSMutableArray class]; // TODO: FIXME:
    Class dictionaryClass = [NSMutableDictionary class]; // TODO: FIXME:
    Class stringClass = [NSString class];
    if (opt & kYAMLReadOptionMutableContainers) {
        arrayClass = [NSMutableArray class];
        dictionaryClass = [NSMutableDictionary class];
        if (opt & kYAMLReadOptionMutableContainersAndLeaves) {
            stringClass = [NSMutableString class];
        }
    }

    yaml_node_t *node = NULL;
    yaml_node_item_t *item = NULL;
    yaml_node_pair_t *pair = NULL;

    int i = 0;

    objects = (id *) calloc(document->nodes.top - document->nodes.start, sizeof(id));
    if (objects == NULL) {
        YAML_SET_ERROR(kYAMLErrorCodeOutOfMemory,  @"Couldn't allocate memory", @"Please try to free memory and retry");
        return nil;
    }

    // Create all objects, don't fill containers yet...
    for (node = document->nodes.start, i = 0; node < document->nodes.top; node++, i++) {
        switch (node->type) {
            case YAML_SCALAR_NODE: {
                id value = [[stringClass alloc] initWithUTF8String: (const char *)node->data.scalar.value];
                yaml_scalar_style_t style = node->data.scalar.style;
                
                if (!(opt & kYAMLReadOptionStringScalars) && (style == YAML_PLAIN_SCALAR_STYLE)) {
                    id parsedValue = ParseNull(value) ?: ParseBoolean(value) ?: ParseNumber(value) ?: ParseDate(value);
                    if (parsedValue) {
                        [value release];
                        value = parsedValue;
                    }
                }
                objects[i] = value;
                if (!root) root = objects[i];
                break;
            }
            case YAML_SEQUENCE_NODE:
            objects[i] = [[arrayClass alloc] initWithCapacity: node->data.sequence.items.top - node->data.sequence.items.start];
            if (!root) root = objects[i];
            break;

            case YAML_MAPPING_NODE:
            objects[i] = [[dictionaryClass alloc] initWithCapacity: node->data.mapping.pairs.top - node->data.mapping.pairs.start];
            if (!root) root = objects[i];
            break;

            default:
            break;
        }
    }

    // Fill in containers
    for (node = document->nodes.start, i = 0; node < document->nodes.top; node++, i++) {
        switch (node->type) {
            case YAML_SEQUENCE_NODE:
                for (item = node->data.sequence.items.start; item < node->data.sequence.items.top; item++)
                    [objects[i] addObject: objects[*item - 1]];
                break;

            case YAML_MAPPING_NODE:
                for (pair = node->data.mapping.pairs.start; pair < node->data.mapping.pairs.top; pair++)
                    [objects[i] setObject: objects[pair->value - 1]
                                   forKey: objects[pair->key - 1]];
            break;

            default:
            break;
        }
    }

    // Retain the root object
    if (root != nil) {
        [root retain];
    }

    // Release all objects. The root object and all referenced (in containers) objects
    // will have retain count > 0
    for (node = document->nodes.start, i = 0; node < document->nodes.top; node++, i++) {
        [objects[i] release];
    }

    if (objects != NULL) {
        free(objects);
    }

    return root;
}

+ (NSMutableArray *) objectsWithYAMLStream: (NSInputStream *) stream
                            options: (YAMLReadOptions) opt
                              error: (NSError **) error
{
    NSMutableArray *documents = [NSMutableArray array];
    id documentObject = nil;

    yaml_parser_t parser;
    yaml_document_t document;
    BOOL done = NO;

    // Open input stream
    [stream open];

    memset(&parser, 0, sizeof(yaml_parser_t));
    if (!yaml_parser_initialize(&parser)) {
        YAML_SET_ERROR(kYAMLErrorCodeParserInitializationFailed, @"Error in yaml_parser_initialize(&parser)", @"Internal error, please let us know about this error");
        return nil;
    }

    yaml_parser_set_input(&parser, __YAMLSerializationParserInputReadHandler, (void *)stream);

    while (!done) {

        if (!yaml_parser_load(&parser, &document)) {
            YAML_SET_ERROR(kYAMLErrorCodeParseError, @"Parse error", @"Make sure YAML file is well formed");
            return nil;
        }

        done = !yaml_document_get_root_node(&document);

        if (!done) {
            documentObject = __YAMLSerializationObjectWithYAMLDocument(&document, opt, error);
            if (error && *error) {
                yaml_document_delete(&document);
            } else {
                [documents addObject: documentObject];
                [documentObject release];
            }
        }

        // TODO: Check if aliases to previous documents are allowed by the specs
        yaml_document_delete(&document);
    }

    yaml_parser_delete(&parser);

    return documents;
}

+ (id) objectWithYAMLStream: (NSInputStream *) stream options: (YAMLReadOptions) opt error: (NSError **) error {
    return [[self objectsWithYAMLStream: stream options: opt error: error] objectAtIndex: 0];
}

+ (NSMutableArray *) objectsWithYAMLData: (NSData *) data
                          options: (YAMLReadOptions) opt
                            error: (NSError **) error;
{
    NSMutableArray *result = nil;
    if (data != nil) {
        NSInputStream *stream = [[NSInputStream alloc] initWithData: data];
        result = [self objectsWithYAMLStream: stream options: opt error: error];
        [stream release];
    }
    return result;
}

+ (id) objectWithYAMLData: (NSData *) data options: (YAMLReadOptions) opt error: (NSError **) error {
    return [[self objectsWithYAMLData: data options: opt error: error] objectAtIndex: 0];
}

+ (NSMutableArray *) objectsWithYAMLString: (NSString *) string
                                   options: (YAMLReadOptions) opt
                                     error: (NSError **) error;
{
    return [self objectsWithYAMLData: [string dataUsingEncoding: NSUTF8StringEncoding]
                             options: opt
                               error: error];
}

+ (id) objectWithYAMLString: (NSString *) string options: (YAMLReadOptions) opt error: (NSError **) error {
    return [[self objectsWithYAMLString: string options: opt error: error] objectAtIndex: 0];
}

#pragma mark Writing YAML

static int
__YAMLSerializationEmitterOutputWriteHandler (void *data, unsigned char *buffer, size_t size) {
    return ([((NSOutputStream *) data) write: buffer maxLength: size] > 0);
}

static int
__YAMLSerializationAddObject (yaml_document_t *document, id value) {
    int result = 0;
    if ([value isKindOfClass: [NSDictionary class]] ) {
        result = yaml_document_add_mapping(document, NULL, YAML_BLOCK_MAPPING_STYLE);
        for (id key in [value allKeys]) {
            int keyIndex = __YAMLSerializationAddObject(document, key);
            int valueIndex = __YAMLSerializationAddObject(document, [value objectForKey: key]);
            yaml_document_get_node(document, keyIndex)->data.scalar.style = YAML_PLAIN_SCALAR_STYLE;  // don't escape key strings
            yaml_document_append_mapping_pair(document, result, keyIndex, valueIndex);
        }
  }
    else if ([value isKindOfClass: [NSArray class]]) {
        result = yaml_document_add_sequence(document, NULL, YAML_BLOCK_SEQUENCE_STYLE);
        for (id element in value) {
            int elementIndex = __YAMLSerializationAddObject(document, element);
            yaml_document_append_sequence_item(document, result, elementIndex);
        }
    }
  else {
        NSString *string = nil;
        yaml_scalar_style_t style = YAML_ANY_SCALAR_STYLE;
        if ([value isKindOfClass: [NSString class]]) {
            string = value;
            style = YAML_DOUBLE_QUOTED_SCALAR_STYLE;
        } else if ([value isKindOfClass:[NSNumber class]] && (strcmp([value objCType], @encode(BOOL)) == 0)) {
            string = [(NSNumber *)value boolValue] ? @"true" : @"false";
            style = YAML_PLAIN_SCALAR_STYLE;
        } else {
            string = [value stringValue];
        }
        result = yaml_document_add_scalar(document, NULL, (yaml_char_t *)[string UTF8String], (int)strlen([string UTF8String]), style);
  }
    return (int) result;
}

+ (BOOL) __YAMLSerializationAddRootObjectAndEmit: (id) object emitter: (yaml_emitter_t *) emitter {
    BOOL result = YES;
    yaml_document_t document;
    memset(&document, 0, sizeof(yaml_document_t));
    int startend_implicit = 1;
    if (yaml_document_initialize(&document, NULL, NULL, NULL, startend_implicit, startend_implicit)) {
        __YAMLSerializationAddObject(&document, object);

        // TODO: check result code.
        yaml_emitter_dump(emitter, &document);
        yaml_document_delete(&document);
    } else {
        //        YAML_SET_ERROR(kYAMLErrorInvalidYamlObject, @"Failed to initialize yaml document", @"Underlying data structure failed to initalize");
        result = NO;
    }
    return result;
}

+ (BOOL) writeObject: (id) object
        toYAMLStream: (NSOutputStream *) stream
           options: (YAMLWriteOptions) opt
             error: (NSError **) error
{
    BOOL result = YES;
    yaml_emitter_t emitter;
    memset(&emitter, 0, sizeof(yaml_emitter_t));

    if (!yaml_emitter_initialize(&emitter)) {
        YAML_SET_ERROR(kYAMLErrorCodeEmitterError, @"Error in yaml_emitter_initialize(&emitter)", @"Internal error, please let us know about this error");
        return NO;
    }

    yaml_emitter_set_encoding(&emitter, YAML_UTF8_ENCODING);
    yaml_emitter_set_unicode(&emitter, 1);
    yaml_emitter_set_output(&emitter, __YAMLSerializationEmitterOutputWriteHandler, (void *)stream);

    // Open output stream.
    [stream open];

    if (kYAMLWriteOptionMultipleDocuments & opt) {

        // YAML is an array of documents.
        for (id child in object) {

            // TODO: Check result code.
            [self __YAMLSerializationAddRootObjectAndEmit: child emitter: &emitter];
        }
    }
    else {

        // YAML is a single document.
        [self __YAMLSerializationAddRootObjectAndEmit: object emitter: &emitter];
    }

    [stream close];
    yaml_emitter_delete(&emitter);

    return result;
}

+ (NSData *) createYAMLDataWithObject: (id) object options: (YAMLWriteOptions) opt error: (NSError **) error {
    NSData *result = nil;
    NSOutputStream *stream = [[NSOutputStream alloc] initToMemory];
    [self writeObject: object toYAMLStream: stream options: opt error: error];
    result = [[stream propertyForKey: NSStreamDataWrittenToMemoryStreamKey] retain];
    [stream release];
    return result;
}

+ (NSData *) YAMLDataWithObject: (id) object options: (YAMLWriteOptions) opt error: (NSError **) error {
    return [[self createYAMLDataWithObject: object options: opt error: error] autorelease];
}

+ (NSString *) createYAMLStringWithObject: (id) object options: (YAMLWriteOptions) opt error: (NSError **) error {
    return [[NSString alloc] initWithData: [self YAMLDataWithObject: object options: opt error: error]
                                 encoding: NSUTF8StringEncoding];

}

+ (NSString *) YAMLStringWithObject: (id) object options: (YAMLWriteOptions) opt error: (NSError **) error {
    return [[self createYAMLStringWithObject: object options: opt error: error] autorelease];
}

#pragma mark Deprecated

+ (NSMutableArray *) YAMLWithStream: (NSInputStream *) stream options: (YAMLReadOptions) opt error: (NSError **) error {
    return [self objectsWithYAMLStream: stream options: opt error: error];
}

+ (NSMutableArray *) YAMLWithData: (NSData *) data options: (YAMLReadOptions) opt error: (NSError **) error {
    return [self objectsWithYAMLData: data options: opt error: error];
}

+ (NSData *) dataFromYAML: (id) object options: (YAMLWriteOptions) opt error: (NSError **) error {
    return [self YAMLDataWithObject: object options: opt error: error];
}

+ (BOOL) writeYAML: (id) object toStream: (NSOutputStream *) stream options: (YAMLWriteOptions) opt error: (NSError **) error {
    return [self writeObject: object toYAMLStream: stream options: opt error: error];
}

@end
