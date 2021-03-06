//
//  SPAlbum.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/20/11.
/*
Copyright (c) 2011, Spotify AB
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Spotify AB nor the names of its contributors may 
      be used to endorse or promote products derived from this software 
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SPOTIFY AB BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "SPAlbum.h"
#import "SPSession.h"
#import "SPImage.h"
#import "SPArtist.h"
#import "SPURLExtensions.h"

@interface SPAlbum ()

@property (nonatomic, readwrite) sp_album *album;
@property (nonatomic, readwrite, strong) SPSession *session;
@property (nonatomic, readwrite, strong) SPImage *cover; 
@property (nonatomic, readwrite, strong) SPArtist *artist;
@property (nonatomic, readwrite, copy) NSURL *spotifyURL;
@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (nonatomic, readwrite, getter=isAvailable) BOOL available;
@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite) sp_albumtype type;
@property (nonatomic, readwrite) NSUInteger year;

-(BOOL)checkLoaded;
-(void)loadAlbumData;

@end

@implementation SPAlbum

static NSMutableDictionary *albumCache;

+(SPAlbum *)albumWithAlbumStruct:(sp_album *)anAlbum inSession:(SPSession *)aSession {
    
    if (albumCache == nil) {
        albumCache = [[NSMutableDictionary alloc] init];
    }
    
    NSValue *ptrValue = [NSValue valueWithPointer:anAlbum];
    
    SPAlbum *cachedAlbum = [albumCache objectForKey:ptrValue];
    
    if (cachedAlbum != nil) {
        return cachedAlbum;
    }
    
    cachedAlbum = [[SPAlbum alloc] initWithAlbumStruct:anAlbum
                                                    inSession:aSession];
    
    [albumCache setObject:cachedAlbum forKey:ptrValue];
    return cachedAlbum;
}

+(SPAlbum *)albumWithAlbumURL:(NSURL *)aURL inSession:(SPSession *)aSession {
	
	if ([aURL spotifyLinkType] == SP_LINKTYPE_ALBUM) {
		sp_link *link = [aURL createSpotifyLink];
		if (link != NULL) {
			sp_album *album = sp_link_as_album(link);
			sp_album_add_ref(album);
			SPAlbum *spAlbum = [self albumWithAlbumStruct:album inSession:aSession];
			sp_link_release(link);
			sp_album_release(album);
			return spAlbum;
		}
	}
	return nil;
}

-(id)initWithAlbumStruct:(sp_album *)anAlbum inSession:(SPSession *)aSession {
    if ((self = [super init])) {
        self.album = anAlbum;
        sp_album_add_ref(self.album);
        self.session = aSession;
        sp_link *link = sp_link_create_from_album(anAlbum);
        if (link != NULL) {
            self.spotifyURL = [NSURL urlWithSpotifyLink:link];
            sp_link_release(link);
        }

        if (!sp_album_is_loaded(album)) {
            [aSession addLoadingObject:self];
        } else {
            [self loadAlbumData];
        }
    }
    return self;
}

-(BOOL)checkLoaded {
    BOOL isLoaded = sp_album_is_loaded(album);
    if (isLoaded) {
        [self loadAlbumData];
    }
	return isLoaded;
}

-(void)loadAlbumData {
    const byte *imageId = sp_album_cover(self.album);
    
    if (imageId != NULL) {
        [self setCover:[SPImage imageWithImageId:imageId
                                              inSession:self.session]];
    }
    
    sp_artist *spArtist = sp_album_artist(self.album);
    if (spArtist != NULL) {
        [self setArtist:[SPArtist artistWithArtistStruct:spArtist inSession:self.session]];
    }
    
	const char *nameCharArray = sp_album_name(self.album);
    if (nameCharArray != NULL) {
        NSString *nameString = [NSString stringWithUTF8String:nameCharArray];
        self.name = [nameString length] > 0 ? nameString : nil;
    } else {
        self.name = nil;
    }

	self.year = sp_album_year(self.album);
	self.type = sp_album_type(self.album);
	self.available = sp_album_is_available(self.album);
	self.loaded = sp_album_is_loaded(self.album);
}

-(void)albumBrowseDidLoad {
	if (self.album) self.year = sp_album_year(self.album);
}

-(NSString *)description {
	return [NSString stringWithFormat:@"%@: %@ by %@", [super description], self.name, self.artist.name];
}

@synthesize album;
@synthesize session;
@synthesize cover;
@synthesize artist;
@synthesize spotifyURL;

@synthesize available;
@synthesize loaded;
@synthesize year;
@synthesize type;
@synthesize name;

-(void)dealloc {
    sp_album_release(album);
}

@end
