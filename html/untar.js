/**
 * untar.js
 *
 * Copyright(c) 2011 Google Inc.
 * Copyright(c) 2015 antimatter15
 *
 * Reference Documentation:
 *
 * TAR format: http://www.gnu.org/software/automake/manual/tar/Standard.html
 */

//var ByteStream = require('./bytestream')

// Removes all characters from the first zero-byte in the string onwards.
var readCleanString = function(bstr, numBytes) {
    var str = bstr.readString(numBytes);
    var zIndex = str.indexOf(String.fromCharCode(0));
    return zIndex != -1 ? str.substr(0, zIndex) : str;
};

// takes a ByteStream and parses out the local file information
function TarLocalFile(bstream) {
    this.isValid = false;

    // Read in the header block
    this.name = readCleanString(bstream, 100);
    this.mode = readCleanString(bstream, 8);
    this.uid = readCleanString(bstream, 8);
    this.gid = readCleanString(bstream, 8);
    
    this.size = parseInt(readCleanString(bstream, 12), 8);
    this.mtime = readCleanString(bstream, 12);
    this.chksum = readCleanString(bstream, 8);
    this.typeflag = readCleanString(bstream, 1);
    this.linkname = readCleanString(bstream, 100);
    this.maybeMagic = readCleanString(bstream, 6);

    // 100+8+8+8+12+12+8+1+100+6 = 263 Bytes

    if (this.maybeMagic == "ustar") {
        this.version = readCleanString(bstream, 2);
        this.uname = readCleanString(bstream, 32);
        this.gname = readCleanString(bstream, 32);
        this.devmajor = readCleanString(bstream, 8);
        this.devminor = readCleanString(bstream, 8);
        this.prefix = readCleanString(bstream, 155);

        // 2+32+32+8+8+155 = 237 Bytes

        if (this.prefix.length) {
            this.name = this.prefix + this.name;
        }
        bstream.readBytes(12); // 512 - 263 - 237
    } else {
        bstream.readBytes(249); // 512 - 263
    }
    
    // Done header, now rest of blocks are the file contents.
    this.filename = this.name;
    this.fileData = null;

    // console.info("Untarring file '" + this.filename + "'");
    // console.info("  size = " + this.size);
    // console.info("  typeflag = " + this.typeflag);

    if (this.typeflag == 0) {
        // console.info("  This is a regular file.");
        var sizeInBytes = parseInt(this.size);
        this.fileData = new Uint8Array(bstream.bytes.buffer, bstream.ptr, this.size);
        if (this.name.length > 0 && this.size > 0 && this.fileData && this.fileData.buffer) {
            this.isValid = true;
        }
    } else if (this.typeflag == 5) {
        // console.info("  This is a directory.")
    }

    bstream.ptr += this.size;
    // Round up to 512-byte blocks.
    var remaining = 512 - bstream.ptr % 512;
    // console.log('remaining')
    if (remaining > 0 && remaining < 512) {
        bstream.readBytes(remaining)
    }
};

function untar(arrayBuffer){
    var bstream = new ByteStream(arrayBuffer);
    var localFiles = [];
    // While we don't encounter an empty block, keep making TarLocalFiles.
    while (bstream.peekNumber(4) != 0) {
        var oneLocalFile = new TarLocalFile(bstream);
        if (oneLocalFile && oneLocalFile.isValid) {
            localFiles.push(oneLocalFile);
            // totalUncompressedBytesInArchive += oneLocalFile.size;
        }
    }
    return localFiles;
}
