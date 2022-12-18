#import <Foundation/Foundation.h>
#include "libarchive.h"

// Make sure that the status from a libarchive function is ok
#define ASSERT_IS_ARCHIVE_OK(status, errorDescription) \
    if (r < ARCHIVE_OK) { \
        *error = errorWithDescription(errorDescription); \
        return; \
    }

static int
copy_data(struct archive *ar, struct archive *aw)
{
  int r;
  const void *buff;
  size_t size;
  la_int64_t offset;

  for (;;) {
    r = archive_read_data_block(ar, &buff, &size, &offset);
    if (r == ARCHIVE_EOF)
      return (ARCHIVE_OK);
    if (r < ARCHIVE_OK)
      return (r);
    r = archive_write_data_block(aw, buff, size, offset);
    if (r < ARCHIVE_OK) {
      fprintf(stderr, "%s\n", archive_error_string(aw));
      return (r);
    }
  }
}

static NSError 
*errorWithDescription(NSString *description) {
    NSDictionary *dict = @{
        NSLocalizedDescriptionKey: description
    };
    
    return [NSError errorWithDomain:@"com.serena.unarchive" code:0 userInfo:dict];
}


void extractPath(NSString *path, NSString *destination, NSError **error)
{
    struct archive *a;
    struct archive *ext;
    struct archive_entry *entry;
    int flags;
    int r;

    /* Select which attributes we want to restore. */
    flags = ARCHIVE_EXTRACT_TIME;
    flags |= ARCHIVE_EXTRACT_PERM;
    flags |= ARCHIVE_EXTRACT_ACL;
    flags |= ARCHIVE_EXTRACT_FFLAGS;

    a = archive_read_new();
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    ext = archive_write_disk_new();
    archive_write_disk_set_options(ext, flags);
    archive_write_disk_set_standard_lookup(ext);
    if ((r = archive_read_open_filename(a, path.fileSystemRepresentation, 10240))) {
        *error = errorWithDescription(@"Failed to open file to extract.");
        return;
    }

    for (;;)
    {
        r = archive_read_next_header(a, &entry);
        if (r == ARCHIVE_EOF)
            break;
        
        ASSERT_IS_ARCHIVE_OK(r, @(archive_error_string(a)))
        
        NSString* currentFile = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
        NSString* fullOutputPath = [destination stringByAppendingPathComponent:currentFile];
        //printf("extracting %@ to %@\n", currentFile, fullOutputPath);
        archive_entry_set_pathname(entry, fullOutputPath.fileSystemRepresentation);
        
        r = archive_write_header(ext, entry);
        ASSERT_IS_ARCHIVE_OK(r, @(archive_error_string(ext)))

        else if (archive_entry_size(entry) > 0) {
            r = copy_data(a, ext);
            ASSERT_IS_ARCHIVE_OK(r, @(archive_error_string(ext)))
        }
        r = archive_write_finish_entry(ext);
        ASSERT_IS_ARCHIVE_OK(r, @(archive_error_string(ext)))
    }
    
    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
}


/*
int main(int argc, char **argv) {
    NSError *error = nil;
    extractPath( @(argv[1]), @(argv[2]), &error );
    if (error) NSLog(@"Error: %@\n", [error localizedDescription]);
}
*/
