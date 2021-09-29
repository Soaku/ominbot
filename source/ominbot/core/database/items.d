module ominbot.core.database.items;

import dlib.image;
import arsd.sqlite;
import std.typecons;

import ominbot.core.bot;
import ominbot.core.image.card;


@safe:


void prepareItems(Sqlite db) @trusted {

    // Perform this in a transaction
    db.query(`BEGIN TRANSACTION`);
    scope (success) db.query(`COMMIT TRANSACTION`);
    scope (failure) db.query(`ROLLBACK TRANSACTION`);

    // Create a registry of all items
    db.query(`

        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,

            -- There will always be exactly 1 to 3 tags. A bit silly, but anyway, it's just decorative anyway.
            tag1 TEXT NOT NULL,
            tag2 TEXT NOT NULL,
            tag3 TEXT NOT NULL,

            -- Type of the item
            type TEXT NOT NULL,

            -- Colors for the item
            primary_color INTEGER NOT NULL,
            secondary_color INTEGER NOT NULL
        )

    `);

    // Create a registry of all item owners
    db.query(`

        CREATE TABLE IF NOT EXISTS inventory (
            id INTEGER PRIMARY KEY NOT NULL,
            owner_id INTEGER,
            item_id INTEGER,
            count INTEGER,
            FOREIGN KEY(item_id) REFERENCES items(id)
        )

    `);
    db.query(`

        CREATE UNIQUE INDEX IF NOT EXISTS inventory_unique ON inventory(owner_id, item_id)

    `);

}

debug void createSamples(Sqlite db) @trusted {

    // Create an item card
    ItemCard card = {

        name: ["foo", "bar", "test", "item"],
        id: 0,

    };

    ItemCard invalidCard = {

        name: ["invalid", "item"],
        id: 0  // duplicate id

    };

    db.query(`DELETE FROM items WHERE id = 0`);

    auto result1 = db.createItem(card);
    auto result2 = db.createItem(invalidCard);

    assert(result1 == card);
    assert(result1 == result2);

}

// TODO: prevent creating an item if the prompt was repeated

/// Registers the item in the database, if no item with given ID already exists.
///
/// Returns: The registered item, or the item returned.
ItemCard createItem(Sqlite db, ItemCard card) @trusted {

    import std.string;

    // Perform this in a transaction
    db.query(`BEGIN TRANSACTION`);
    scope (success) db.query(`COMMIT TRANSACTION`);
    scope (failure) db.query(`ROLLBACK TRANSACTION`);

    try db.query(
        `INSERT INTO items(id, name, type, tag1, tag2, tag3, primary_color, secondary_color)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        card.id, card.name.join(" "), card.type, card.tags[0], card.tags[1], card.tags[2],
        card.palette.primary.toInt, card.palette.secondary.toInt
    );
    // TODO: add tags on insertion

    // Item already exists
    // TODO: update tag list
    catch (DatabaseException exc) {

        return db.getItem(card.id);

    }

   return card;

}

/// Get an item from the database by number.
ItemCard getItem(Sqlite db, uint id) @trusted {

    import std.format, std.exception;

    auto result = db.query(`SELECT * FROM items WHERE id=?`, id);

    // TODO: some other exception
    enforce(result.length == 1, id.format!"No item with ID %s found");

    // Return the found item
    return result.front.readCard();

}

void giveItem(Sqlite db, const ItemCard card, size_t owner, size_t count = 1) @trusted {

    db.query(
        `INSERT OR REPLACE INTO inventory(owner_id, item_id, count)
        VALUES (?1, ?2, ?3 + COALESCE(
            (SELECT count FROM inventory WHERE owner_id = ?1 AND item_id = ?2),
            0
        ))`,
        owner, card.id, count
    );

}

bool takeItem(Sqlite db, ItemCard card, size_t owner, size_t count = 1) @trusted {

    assert(false, "unimplemented");

}

/// Returns: A list of items and the number owned by the user.
Tuple!(ItemCard, size_t)[] listItems(Sqlite db, size_t owner, size_t page = 1) @trusted {

    import std.conv;

    auto result = db.query(
        `SELECT items.*, inventory.count FROM inventory JOIN items
        ON inventory.item_id = items.id
        WHERE inventory.owner_id = ?
        ORDER BY items.id
        LIMIT 10 OFFSET ?`,
        owner, (page-1) * 10
    );

    typeof(return) cards;

    foreach (row; result) {

        cards ~= tuple(readCard(row), row["count"].to!size_t);

    }

    return cards;

}

private ItemCard readCard(Row row) @trusted {

    import std.conv, std.string;

    ItemCard card = {
        id: row["id"].to!uint,
        name: row["name"].split(" "),
        tags: [row["tag1"], row["tag2"], row["tag3"]],
        type: row["type"].to!ItemType,
        palette: ColorPalette(
            color3(row["primary_color"].to!int),
            color3(row["secondary_color"].to!int),
        ),
    };

    return card;

}

private int toInt(Color4f color) {

    import std.conv, std.math;

    return (round(color[0] * 255).to!int << 16)
        + (round(color[1] * 255).to!int << 8)
        + (round(color[2] * 255).to!int);

}

@system
unittest {

    const color = color3(0xb0b0b0);
    assert(color.toInt == 0xb0b0b0);

}