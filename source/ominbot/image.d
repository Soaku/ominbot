module ominbot.image;

import std.file;
import std.path;
import std.array;
import std.format;
import std.random;
import std.string;
import std.algorithm;
import std.stdio : writefln;

import dlib.math;
import dlib.image;

import ominbot.bot;
import ominbot.params;

struct BitmapCharacter {

    uint x, y, width;

}

struct WordData {

    uint width;
    BitmapCharacter[] characters;

}

private {

    immutable {

        auto textHeight = 61;
        auto spaceWidth = 20;
        BitmapCharacter[dchar] fontChars;

    }

    SuperImage fontBitmap;

}

shared static this() {

    alias BC = BitmapCharacter;

    fontChars = [

        'A': BC(   0, 0, 43),
        'B': BC(  44, 0, 39),
        'C': BC(  87, 0, 41),
        'D': BC( 132, 0, 40),
        'E': BC( 176, 0, 33),
        'F': BC( 212, 0, 32),
        'G': BC( 246, 0, 41),
        'H': BC( 291, 0, 40),
        'I': BC( 335, 0, 23),
        'J': BC( 361, 0, 28),
        'K': BC( 394, 0, 41),
        'L': BC( 437, 0, 31),
        'M': BC( 471, 0, 50),
        'N': BC( 525, 0, 39),
        'O': BC( 568, 0, 41),
        'P': BC( 613, 0, 38),
        'Q': BC( 653, 0, 41),
        'R': BC( 698, 0, 39),
        'S': BC( 739, 0, 41),
        'T': BC( 780, 0, 39),
        'U': BC( 821, 0, 41),
        'V': BC( 863, 0, 44),
        'W': BC( 905, 0, 61),
        'X': BC( 965, 0, 41),
        'Y': BC(1005, 0, 41),
        'Z': BC(1045, 0, 34),

        '0': BC(   2, 144, 40),
        '1': BC(  43, 144, 32),
        '2': BC(  79, 144, 39),
        '3': BC( 120, 144, 40),
        '4': BC( 161, 144, 42),
        '5': BC( 204, 144, 40),
        '6': BC( 247, 144, 41),
        '7': BC( 288, 144, 34),
        '8': BC( 325, 144, 38),
        '9': BC( 367, 144, 41),
        '-': BC( 453, 144, 27),
        '!': BC( 482, 144, 25),
        '?': BC( 510, 144, 39),

    ];

}

/// Mutilate an image.
/// Returns: True if done.
bool mutilateImage(ref Ominbot bot) {

    return mutilateImage(bot.statusUpdate, bot.statusUpdate);

}

bool mutilateImage(string[] top, string[] bottom) {

    if (fontBitmap is null) {

        fontBitmap = loadImage("resources/bot-impact.png");

    }

    auto images = "resources".dirEntries("bot-img-*.png", SpanMode.shallow);
    if (images.empty) return false;

    const editOwn = ImageOutputPath.exists && uniform(0, ImageEditOwnRarity) == 0;

    const imagePath = editOwn
        ? ImageOutputPath
        : images.array.choice;


    writefln!"Proceeding to mutilate image %s..."(imagePath);

    auto image = loadImage(imagePath);

    // Add text
    image.addText(top, 0);
    image.addText(bottom, image.height - textHeight);

    // Save
    image.savePNG(ImageOutputPath);

    writefln!"Mutilated an image and saved";

    return true;

}

unittest {

    mutilateImage(["abcdef?!"], ["1234567890"]);

}

/// Add text to given image in place.
void addText(SuperImage a, string[] words, uint offsetY) {

    foreach (line; spreadText(words, a.width)) {

        scope (exit) offsetY += textHeight;

        const lineWidth = line
            .map!(a => a.width + spaceWidth)
            .fold!"a + b"
            - spaceWidth;

        // Make sure the text is centered
        auto position = (cast(int) a.width - lineWidth) / 2;

        // Generate the line
        foreach (word; line) {

            scope (exit) position += spaceWidth;

            foreach (letter; word.characters) {

                a.addImage(
                    fontBitmap.region(letter.x, letter.y, letter.width, textHeight),
                    position, offsetY,
                );

                position += letter.width;

            }

        }

    }

}

private const(WordData)[][] spreadText(string[] words, uint imageWidth) {

    const(WordData)[][] lines = [[]];

    uint lineWidth;

    // Calculate
    foreach (word; words) {

        const data = wordData(word);
        const wordWidth = data.width + spaceWidth;

        // Can fit on this line, or the line is empty
        if (!lines[$-1].length || lineWidth + data.width <= imageWidth) {

            lineWidth += wordWidth;
            lines[$-1] ~= data;

        }

        // Nope
        else {

            lineWidth = wordWidth;
            lines ~= [data];

        }

    }

    return lines;

}

/// Calculate the width of the word.
private WordData wordData(string word) {

    WordData result;

    foreach (letter; word.toUpper) {

        auto item = letter in fontChars;
        if (item is null) continue;

        result.width += item.width;
        result.characters ~= *item;

    }

    return result;

}

/// Combine two images. Modifies the first image in place.
private void addImage(SuperImage a, ImageRegion b, uint offsetX, uint offsetY) {

    foreach (y; 0 .. b.height) {

        auto ay = y + offsetY;
        if (ay >= a.height) break;

        foreach (x; 0 .. b.width) {

            auto ax = x + offsetX;
            if (ax >= a.width) break;

            const black = vec4(0, 0, 0, 1);

            const aPixel = a[ax, ay];
            const aAlpha = aPixel[3];
            const aTransparent = aPixel * vec4(1, 1, 1, 0);

            const bPixel = b.img[b.xstart + x, b.ystart + y];
            const bAlpha = bPixel[3];
            const bTransparent = bPixel * vec4(1, 1, 1, 0);

            a[ax, ay] = Color4f(
                + aTransparent * (1 - bAlpha)
                + bTransparent * bAlpha
                + black * max(aAlpha, bAlpha)
            );

        }

    }

}
