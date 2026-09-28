// Sample mongosh script: query the `customers` collection.
// Run with:  mongosh "mongodb://<host>:27017/<db>" query-customers.js
// Or interactively:  mongosh --file query-customers.js

const dbName = 'sales';
const coll = db.getSiblingDB(dbName).customers;

print(`\n--- Count ---`);
print(`Total customers: ${coll.countDocuments()}`);

print(`\n--- First 5 documents ---`);
coll.find().limit(5).forEach(doc => printjson(doc));

print(`\n--- Active customers in WA, newest first ---`);
coll.find(
    { status: 'active', state: 'WA' },
    { _id: 0, name: 1, email: 1, state: 1, createdAt: 1 }
)
.sort({ createdAt: -1 })
.limit(10)
.forEach(doc => printjson(doc));

print(`\n--- Customer count by state (top 10) ---`);
coll.aggregate([
    { $group: { _id: '$state', customers: { $sum: 1 } } },
    { $sort: { customers: -1 } },
    { $limit: 10 }
]).forEach(doc => printjson(doc));
