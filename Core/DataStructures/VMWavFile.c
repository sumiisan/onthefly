//
//  VMWavFile.c
//  OnTheFly
//
//  Created by cboy mbp m1 on 2021/01/03.
//

#include "VMWavFile.h"
#include <string.h>
    
static uint32_t largestCueId(WaveFile *wf) {
    return 0;   // TODO: implement
}
    
static void setCueSize(WaveFile *wf, uint32_t numberOfCuePoints) {
    wf->numberOfCuePoints = numberOfCuePoints;
    uint32ToLittleEndianBytes(wf->numberOfCuePoints, wf->cueChunk.numberOfCuePoints);
    uint32_t dataSize = 4 + sizeof(CuePoint) * numberOfCuePoints;
    uint32ToLittleEndianBytes(dataSize, wf->cueChunk.chunkDataSize);
}
    
WaveFile newWaveFile(const char *filePath) {
    WaveFile wf;
    wf.filePath = filePath;
    wf.header = (const WaveHeader){{0}};
    wf.formatChunk = (const FormatChunk){{0}};
    wf.formatChunkExtraBytes = (const ChunkLocation){0, 0};
    wf.cueChunk = (const CueChunk){{0}};
    wf.cueChunk.cuePoints = NULL;
    wf.dataChunkLocation = (const ChunkLocation){0, 0};
    wf.otherChunksCount = 0;
    wf.cueChunk = (const CueChunk){{0}};
    wf.numberOfCuePoints = 0;
    
    wf.file = fopen(wf.filePath, "rb");
    return wf;
}

void freeWaveFile(WaveFile *wf) {
    int i;
    
    if (wf->file != NULL) fclose(wf->file);
    if (wf->cueChunk.cuePoints != NULL) free(wf->cueChunk.cuePoints);
    if (wf->listChunk.labelsPtr != NULL) {
        for (i = 0; i < wf->numberOfCuePoints; ++i) {
            free(wf->listChunk.labelsPtr[i]->data);
            free(wf->listChunk.labelsPtr[i]);
        }
        free(wf->listChunk.labelsPtr);
    }
    if (wf->listChunk.labeledTextsPtr != NULL) {
        for (i = 0; i < wf->numberOfCuePoints; ++i) {
            free(wf->listChunk.labeledTextsPtr[i]->data);
            free(wf->listChunk.labeledTextsPtr[i]);
        }
        free(wf->listChunk.labeledTextsPtr);
    }
}

#define abortOnError(CONDITION, MESSAGE) if (CONDITION) {\
    fprintf(stderr, MESSAGE);\
    goto CleanUpAndExit;\
}

int readWavfile(WaveFile *wf) {
    // Open the Input File
    abortOnError(wf->file == NULL, "Could not open file\n")
    
    // Get & check the input file header
    fprintf(stdout, "Reading wave file.\n");
    
    fread(&(wf->header), sizeof(WaveHeader), 1, wf->file);
    abortOnError(ferror(wf->file) != 0, "Error reading file\n");
    abortOnError(strncmp(&(wf->header.chunkID[0]), "RIFF", 4) != 0, "File is not a RIFF file\n");
    abortOnError(strncmp(&(wf->header.riffType[0]), "WAVE", 4) != 0, "File is not a WAVE fi.\n");
    
    uint32_t remainingFileSize = littleEndianBytesToUInt32(wf->header.dataSize) - sizeof(wf->header.riffType); // dataSize does not counf the chunkID or the dataSize, so remove the riffType size to get the length of the rest of the file.
    abortOnError(remainingFileSize <= 0, "File is an empty WAVE file\n");
    
    // Start reading in the rest of the wave file
    while (1) {
        char nextChunkID[4];
        
        // Read the ID of the next chunk in the file, and bail if we hit End Of File
        fread(&nextChunkID[0], sizeof(nextChunkID), 1, wf->file);
        if (feof(wf->file))
            break;
        
        abortOnError(ferror(wf->file) != 0, "Error reading file\n");

        // See which kind of chunk we have
        if (strncmp(&nextChunkID[0], "fmt ", 4) == 0) {
            // We found the format chunk

            fseek(wf->file, -4, SEEK_CUR);
            fread(&(wf->formatChunk), sizeof(FormatChunk), 1, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");
            abortOnError(littleEndianBytesToUInt16(wf->formatChunk.compressionCode) != (uint16_t)1,
                         "Compressed audio formats are not supported\n");
            
            // Note: For compressed audio data there may be extra bytes appended to the format chunk,
            // but as we are only handling uncompressed data we shouldn't encounter them
            
            // There may or may not be extra data at the end of the fomat chunk.  For uncompressed audio there should be no need, but some files may still have it.
            // if formatChunk.chunkDataSize > 16 (16 = the number of bytes for the format chunk, not counting the 4 byte ID and the chunkDataSize itself) there is extra data
            uint32_t extraFormatBytesCount = littleEndianBytesToUInt32(wf->formatChunk.chunkDataSize) - 16;
            if (extraFormatBytesCount > 0) {
                wf->formatChunkExtraBytes.startOffset = ftell(wf->file);
                wf->formatChunkExtraBytes.size = extraFormatBytesCount;
                fseek(wf->file, extraFormatBytesCount, SEEK_CUR);
                if (extraFormatBytesCount % 2 != 0) {
                    fseek(wf->file, 1, SEEK_CUR);
                }
            }
            printf("Got Format Chunk\n");
        }
        
        else if (strncmp(&nextChunkID[0], "data", 4) == 0) {
            // We found the data chunk
            wf->dataChunkLocation.startOffset = ftell(wf->file) - sizeof(nextChunkID);
            
            // The next 4 bytes are the chunk data size - the size of the sample data
            char sampleDataSizeBytes[4];
            fread(sampleDataSizeBytes, sizeof(char), 4, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");
            
            uint32_t sampleDataSize = littleEndianBytesToUInt32(sampleDataSizeBytes);
            wf->dataChunkLocation.size = sizeof(nextChunkID) + sizeof(sampleDataSizeBytes) + sampleDataSize;
            
            // Skip to the end of the chunk.  Chunks must be aligned to 2 byte boundaries, but any padding at the end of a chunk is not included in the chunkDataSize
            fseek(wf->file, sampleDataSize, SEEK_CUR);
            if (sampleDataSize % 2 != 0) {
                fseek(wf->file, 1, SEEK_CUR);
            }
            printf("Got Data Chunk\n");
        }
        
        else if (strncmp(&nextChunkID[0], "cue ", 4) == 0) {
            // We found an existing Cue Chunk
            char cueChunkDataSizeBytes[4];
            fread(cueChunkDataSizeBytes, sizeof(char), 4, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");

            char cuePointsCountBytes[4];
            fread(cuePointsCountBytes, sizeof(char), 4, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");

            uint32_t numberOfCuePoints = littleEndianBytesToUInt16(cuePointsCountBytes);
            
            // Read in the existing cue points into CuePoint Structs
            CuePoint *readCuePoints = (CuePoint *)malloc(sizeof(CuePoint) * numberOfCuePoints);
            for (uint32_t cuePointIndex = 0; cuePointIndex < numberOfCuePoints; cuePointIndex++) {
                fread(&readCuePoints[cuePointIndex], sizeof(CuePoint), 1, wf->file);
                abortOnError(ferror(wf->file) != 0, "Error reading file\n");
            }
            
            // Populate the CueChunk struct
            wf->cueChunk.chunkID[0] = 'c';
            wf->cueChunk.chunkID[1] = 'u';
            wf->cueChunk.chunkID[2] = 'e';
            wf->cueChunk.chunkID[3] = ' ';
            setCueSize(wf, numberOfCuePoints);

            wf->cueChunk.cuePoints = readCuePoints;
            
            printf("Got Cue Chunk\n");
        }
        
        else if (strncmp(&nextChunkID[0], "LIST", 4) == 0) {
            // our target: regions
            fread(&(wf->listChunk.listChunkDataSize), sizeof(char), 4, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");
            uint32_t listChunkSize = littleEndianBytesToUInt16(wf->listChunk.listChunkDataSize);

            fread(&(wf->listChunk.listTypeID), sizeof(char), 4, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");
            abortOnError(strncmp(wf->listChunk.listTypeID, "adtl", 4) != 0, "LIST type should be 'adtl'\n");

            printf("Read LIST chunk with size:%d type:%c%c%c%c\n",
                   listChunkSize, wf->listChunk.listTypeID[0], wf->listChunk.listTypeID[1], wf->listChunk.listTypeID[2], wf->listChunk.listTypeID[3]);

            int dataSize = listChunkSize - 12;  // chunkID, chunkSize, listTypeID = 12bytes
            int bytesLeft = dataSize;
            
            wf->listChunk.labelsPtr = calloc(wf->numberOfCuePoints, sizeof(ListLabelNote *));
            wf->listChunk.labeledTextsPtr = calloc(wf->numberOfCuePoints, sizeof(ListLabeledText *));

            int labelIdx = 0, labeledTextIdx = 0;
            
            while(bytesLeft > 0) {
                char subChunkID[4];
                char subChunkSizeBytes[4];

                fread(subChunkID, sizeof(char), 4, wf->file);
                fread(subChunkSizeBytes, sizeof(char), 4, wf->file);
                uint32_t subChunkSize = littleEndianBytesToUInt16(subChunkSizeBytes);
                uint32_t cuePointIdNum;

                fseek(wf->file, -8, SEEK_CUR);  // rewind fread subChunkID and subChunkSizeBytes
                
                if (strncmp(subChunkID, "labl", 4) == 0 || strncmp(subChunkID, "note", 4) == 0) {
                    // labl or note
                    ListLabelNote *label = malloc(sizeof(ListLabelNote));
                    wf->listChunk.labelsPtr[labelIdx++] = label;
                    
                    fread(label, 12 /*sizeof(ListLabelNote) - sizeof(label->data)*/, 1, wf->file);
                    uint32_t lablDataSize = subChunkSize - 4 /*size of cuePointID*/;
                    label->data = malloc(lablDataSize+1);
                    fread(label->data, lablDataSize, 1, wf->file);
                    label->data[lablDataSize] = 0; //terminate

                    cuePointIdNum = littleEndianBytesToUInt16(label->cuePointID);

                    printf("SubChunk[%c%c%c%c] size:%d cuePointId:%d\ndata(%dbytes):%s\n\n",
                           subChunkID[0], subChunkID[1], subChunkID[2], subChunkID[3],
                           subChunkSize, cuePointIdNum,
                           lablDataSize, label->data
                           );
                    
                } else if (strncmp(subChunkID, "ltxt", 4) == 0) {
                    // ltxt
                    ListLabeledText *ltext = malloc(sizeof(ListLabeledText));
                    wf->listChunk.labeledTextsPtr[labeledTextIdx++] = ltext;

                    fread(ltext, 28/*sizeof(ListLabeledText) - sizeof(ltext->data);*/, 1, wf->file);
                    uint32_t ltxtDataSize = subChunkSize - 20 /*size of ListLabeledText minus size of cuePointID*/;
                    ltext->data = malloc(ltxtDataSize+1);
                    fread(ltext->data, ltxtDataSize, 1, wf->file);
                    ltext->data[ltxtDataSize] = 0; //terminate
                    
                    cuePointIdNum = littleEndianBytesToUInt16(ltext->cuePointID);
                    uint32_t sampleLength = littleEndianBytesToUInt16(ltext->sampleLengthBytes);
                    
                    printf(" SubChunk[%c%c%c%c] size:%d cuePointId:%d\n"
                           " samplelen:%d purpose:%c%c%c%c\n data(%dbytes):%s\n\n",
                           subChunkID[0], subChunkID[1], subChunkID[2], subChunkID[3],
                           subChunkSize, cuePointIdNum,
                           sampleLength,
                           ltext->purposeIDBytes[0], ltext->purposeIDBytes[1], ltext->purposeIDBytes[2], ltext->purposeIDBytes[3],
                           ltxtDataSize,
                           ltext->data
                           );
                } else {
                    // fatal
                    abortOnError(1, "bad sub chunk ID");
                }
                
                bytesLeft -= (subChunkSize + 8);
            }
        }
        
        else {
            // We have found a chunk type that we are not going to work with.
            // Just note the location so we can copy it to the output file later
            
            abortOnError(wf->otherChunksCount >= kMaxNumOfOtherChunks, "File has more chunks than the maximum supported by this program\n");
            
            wf->otherChunkLocations[wf->otherChunksCount].startOffset = ftell(wf->file) - sizeof(nextChunkID);
            
            char chunkDataSizeBytes[4] = {0};
            fread(chunkDataSizeBytes, sizeof(char), 4, wf->file);
            abortOnError(ferror(wf->file) != 0, "Error reading file\n");

            uint32_t chunkDataSize = littleEndianBytesToUInt32(chunkDataSizeBytes);
            
            wf->otherChunkLocations[wf->otherChunksCount].size = sizeof(nextChunkID) + sizeof(chunkDataSizeBytes) + chunkDataSize;
            
            // Skip over the chunk's data, and any padding byte
            fseek(wf->file, chunkDataSize, SEEK_CUR);
            if (chunkDataSize % 2 != 0) {
                fseek(wf->file, 1, SEEK_CUR);
            }
            
            wf->otherChunksCount++;
            
            fprintf(stdout, "Found chunk type \'%c%c%c%c\', size: %d bytes\n", nextChunkID[0], nextChunkID[1], nextChunkID[2], nextChunkID[3], chunkDataSize);
        }
    }
    
    // Did we get enough data from the input file to proceed?
    
    abortOnError(wf->dataChunkLocation.size == 0,
                 "Input file did not contain any format data or did not contain any sample data\n");
    
    return 0;      // successful read completion

CleanUpAndExit:
    freeWaveFile(wf);
    return -1;
}

ListLabelNote *findLabelById(WaveFile *wf, char *id) {
    for(int i = 0; i < wf->numberOfCuePoints; ++i) {
        ListLabelNote *label = wf->listChunk.labelsPtr[i];
        if (!label) break;
        if (memcmp(label->cuePointID, id, 4) == 0) {
            return label;
        }
    }
    return NULL;
}

ListLabeledText *findLabeledTextById(WaveFile *wf, char *id) {
    for(int i = 0; i < wf->numberOfCuePoints; ++i) {
        ListLabeledText *ltext = wf->listChunk.labeledTextsPtr[i];
        if (!ltext) break;
        if (memcmp(ltext->cuePointID, id, 4) == 0) {
            return ltext;
        }
    }
    return NULL;
}

int addCue(WaveFile *wf, uint32_t location) {
    // copy into new CuePoint memory
    CuePoint *newCPs = (CuePoint *)malloc(sizeof(CuePoint) * (wf->numberOfCuePoints+1));
    if(newCPs == NULL) return -1;
    
    memcpy(newCPs, wf->cueChunk.cuePoints, sizeof(CuePoint) * wf->numberOfCuePoints);
    CuePoint *newCP = &(newCPs[wf->numberOfCuePoints]);
    
    uint32_t cueId = largestCueId(wf) + 1;
    
    uint32ToLittleEndianBytes(cueId, newCP->cuePointID);
    uint32ToLittleEndianBytes(0, newCP->playOrderPosition);
    newCP->dataChunkID[0] = 'd';
    newCP->dataChunkID[1] = 'a';
    newCP->dataChunkID[2] = 't';
    newCP->dataChunkID[3] = 'a';
    uint32ToLittleEndianBytes(0, newCP->chunkStart);
    uint32ToLittleEndianBytes(0, newCP->blockStart);
    uint32ToLittleEndianBytes(location, newCP->frameOffset);
    
    wf->numberOfCuePoints += 1;
    uint32ToLittleEndianBytes(wf->numberOfCuePoints, wf->cueChunk.numberOfCuePoints);
    
    setCueSize(wf, wf->numberOfCuePoints);
    free(wf->cueChunk.cuePoints);
    wf->cueChunk.cuePoints = newCPs;
    
    return 0;
}

int deleteCue(WaveFile *wf, uint32_t cueId) {
    // implemenent LATER
    return 0;
}
 
int writeWavFile(WaveFile *wf) {
    // Open the output file for writing
    FILE *readFile = NULL;
    char *tempFilePath = malloc(sizeof(char) * strlen(wf->filePath) + 5);
    strcpy(tempFilePath, wf->filePath);
    strcat(tempFilePath, ".tmp");
    
    wf->file = fopen(tempFilePath, "wb");
    abortOnError(wf->file == NULL, "Could not open output file");
    readFile = fopen(wf->filePath, "rb");
    abortOnError(readFile == NULL, "Could not open output file");

    // Update the file header chunk to have the new data size
    uint32_t fileDataSize = 0;
    fileDataSize += 4; // the 4 bytes for the Riff Type "WAVE"
    fileDataSize += sizeof(FormatChunk);
    fileDataSize += wf->formatChunkExtraBytes.size;
    if (wf->formatChunkExtraBytes.size % 2 != 0) {
        fileDataSize++; // Padding byte for 2byte alignment
    }
    
    fileDataSize += wf->dataChunkLocation.size;
    if (wf->dataChunkLocation.size % 2 != 0) {
        fileDataSize++;
    }
    
    for (int i = 0; i < wf->otherChunksCount; i++) {
        fileDataSize += wf->otherChunkLocations[i].size;
        if (wf->otherChunkLocations[i].size % 2 != 0) {
            fileDataSize ++;
        }
    }
    
    fileDataSize += 4; // 4 bytes for CueChunk ID "cue "
    fileDataSize += 4; // UInt32 for CueChunk.chunkDataSize
    fileDataSize += 4; // UInt32 for CueChunk.cuePointsCount
    fileDataSize += (sizeof(CuePoint) * wf->numberOfCuePoints);
    
    uint32ToLittleEndianBytes(fileDataSize, wf->header.dataSize);
    
    // Write out the header to the new file
    abortOnError(fwrite(&(wf->header), sizeof(WaveHeader), 1, wf->file) < 1,
                 "Error writing header to output file.\n");
    
    // Write out the format chunk
    abortOnError(fwrite(&(wf->formatChunk), sizeof(FormatChunk), 1, wf->file) < 1,
                 "Error writing format chunk to output file.\n");

    if (wf->formatChunkExtraBytes.size > 0) {
        abortOnError(writeChunkLocationFromInputFileToOutputFile(wf->formatChunkExtraBytes, readFile, wf->file) < 0,
                     "Error copying formatChunkExtraBytes");
        if (wf->formatChunkExtraBytes.size % 2 != 0) {
            abortOnError(fwrite("\0", sizeof(char), 1, wf->file) < 1, "Error writing padding character to output file.\n");
        }
    }
    
    // Write out the start of new Cue Chunk: chunkID, dataSize and cuePointsCount
    abortOnError((fwrite(&(wf->cueChunk), sizeof(wf->cueChunk.chunkID) + sizeof(wf->cueChunk.chunkDataSize)+ sizeof(wf->cueChunk.numberOfCuePoints), 1, wf->file) < 1),
                 "Error writing cue chunk header to output file.\n");
    
    // Write out the Cue Points
    for (uint32_t i = 0; i < littleEndianBytesToUInt32(wf->cueChunk.numberOfCuePoints); i++) {
        abortOnError((fwrite(&(wf->cueChunk.cuePoints[i]), sizeof(CuePoint), 1, wf->file) < 1), "Error writing cue point to output");
    }
        
    // Write out the other chunks from the input file
    for (int i = 0; i < wf->otherChunksCount; i++) {
        abortOnError((writeChunkLocationFromInputFileToOutputFile(wf->otherChunkLocations[i], readFile, wf->file) < 0),
                     "Error copying other chunks");
        if (wf->otherChunkLocations[i].size % 2 != 0) {
            abortOnError((fwrite("\0", sizeof(char), 1, wf->file) < 1),
                         "Error writing padding character to output file.\n");
        }
    }
    
    // Write out the data chunk
    abortOnError((writeChunkLocationFromInputFileToOutputFile(wf->dataChunkLocation, readFile, wf->file) < 0),
                 "Error copying data chunk");
    if (wf->dataChunkLocation.size % 2 != 0) {
        abortOnError((fwrite("\0", sizeof(char), 1, wf->file) < 1),
                     "Error writing padding character to output file.\n");
    }
    
    // replace file with temp file
    remove(wf->filePath);
    rename(tempFilePath, wf->filePath);
    
    printf("Finished.\n");
    
    return 0;
    
CleanUpAndExit:
    if (tempFilePath != NULL) free(tempFilePath);
    if (readFile != NULL) fclose(readFile);
    freeWaveFile(wf);
    return -1;
}

int writeChunkLocationFromInputFileToOutputFile(ChunkLocation chunk, FILE *inputFile, FILE *outputFile) {
    // note the position of he input filr to restore later
    long inputFileOrigLocation = ftell(inputFile);
    
    if (fseek(inputFile, chunk.startOffset, SEEK_SET) < 0)
    {
        fprintf(stderr, "Error: could not seek input file to location %ld", chunk.startOffset);
        return -1;
    }
    
    long remainingBytesToWrite = chunk.size;
    while (remainingBytesToWrite >= 1024) {
        char buffer[1024];
        
        fread(buffer, sizeof(char), 1024, inputFile);
        if (ferror(inputFile) != 0) {
            fprintf(stderr, "Copy chunk: Error reading input file");
            fseek(inputFile, inputFileOrigLocation, SEEK_SET);
            return -1;
        }
        
        if (fwrite(buffer, sizeof(char), 1024, outputFile) < 1) {
            fprintf(stderr, "Copy chunk: Error writing output file");
            fseek(inputFile, inputFileOrigLocation, SEEK_SET);
            return -1;
        }
        remainingBytesToWrite -= 1024;
    }
    
    if (remainingBytesToWrite > 0) {
        char buffer[remainingBytesToWrite];
        
        fread(buffer, sizeof(char), remainingBytesToWrite, inputFile);
        if (ferror(inputFile) != 0) {
            fprintf(stderr, "Copy chunk: Error reading input file");
            fseek(inputFile, inputFileOrigLocation, SEEK_SET);
            return -1;
        }
        
        if (fwrite(buffer, sizeof(char), remainingBytesToWrite, outputFile) < 1) {
            fprintf(stderr, "Copy chunk: Error writing output file");
            fseek(inputFile, inputFileOrigLocation, SEEK_SET);
            return -1;
        }
    }
    
    return 0;
}

enum HostEndiannessType getHostEndianness() {
    int i = 1;
    char *p = (char *)&i;
    
    if (p[0] == 1)
        return LittleEndian;
    else
        return BigEndian;
}

uint32_t littleEndianBytesToUInt32(char littleEndianBytes[4]) {
    if (HostEndianness == EndiannessUndefined)
    {
        HostEndianness = getHostEndianness();
    }
    
    uint32_t uInt32Value;
    char *uintValueBytes = (char *)&uInt32Value;
    
    if (HostEndianness == LittleEndian)
    {
        uintValueBytes[0] = littleEndianBytes[0];
        uintValueBytes[1] = littleEndianBytes[1];
        uintValueBytes[2] = littleEndianBytes[2];
        uintValueBytes[3] = littleEndianBytes[3];
    }
    else
    {
        uintValueBytes[0] = littleEndianBytes[3];
        uintValueBytes[1] = littleEndianBytes[2];
        uintValueBytes[2] = littleEndianBytes[1];
        uintValueBytes[3] = littleEndianBytes[0];
    }
    
    return uInt32Value;
}


void uint32ToLittleEndianBytes(uint32_t uInt32Value, char out_LittleEndianBytes[4]) {
    if (HostEndianness == EndiannessUndefined)
    {
        HostEndianness = getHostEndianness();
    }
    
    char *uintValueBytes = (char *)&uInt32Value;
    
    if (HostEndianness == LittleEndian)
    {
        out_LittleEndianBytes[0] = uintValueBytes[0];
        out_LittleEndianBytes[1] = uintValueBytes[1];
        out_LittleEndianBytes[2] = uintValueBytes[2];
        out_LittleEndianBytes[3] = uintValueBytes[3];
    }
    else
    {
        out_LittleEndianBytes[0] = uintValueBytes[3];
        out_LittleEndianBytes[1] = uintValueBytes[2];
        out_LittleEndianBytes[2] = uintValueBytes[1];
        out_LittleEndianBytes[3] = uintValueBytes[0];
    }
}

uint16_t littleEndianBytesToUInt16(char littleEndianBytes[2]) {
    if (HostEndianness == EndiannessUndefined)
    {
        HostEndianness = getHostEndianness();
    }
    
    uint32_t uInt16Value;
    char *uintValueBytes = (char *)&uInt16Value;
    
    if (HostEndianness == LittleEndian)
    {
        uintValueBytes[0] = littleEndianBytes[0];
        uintValueBytes[1] = littleEndianBytes[1];
    }
    else
    {
        uintValueBytes[0] = littleEndianBytes[1];
        uintValueBytes[1] = littleEndianBytes[0];
    }
    
    return uInt16Value;
}

void uint16ToLittleEndianBytes(uint16_t uInt16Value, char out_LittleEndianBytes[2]) {
    if (HostEndianness == EndiannessUndefined)
    {
        HostEndianness = getHostEndianness();
    }
    
    char *uintValueBytes = (char *)&uInt16Value;
    
    if (HostEndianness == LittleEndian)
    {
        out_LittleEndianBytes[0] = uintValueBytes[0];
        out_LittleEndianBytes[1] = uintValueBytes[1];
    }
    else
    {
        out_LittleEndianBytes[0] = uintValueBytes[1];
        out_LittleEndianBytes[1] = uintValueBytes[0];
    }
}
