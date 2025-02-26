const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const fs = require('fs');

const TOKEN = 'TelegramBotToken';
const DATA_FILE = '/root/botpy/user_data.json';
const API_URL = "https://alps.dill.xyz/api/trpc/stats.getAllValidators";

const bot = new TelegramBot(TOKEN, { polling: true });
let userPubkeys = {};
let userBalanceHistory = {};

// Load data from file
function loadData() {
    try {
        const data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
        userPubkeys = data.userPubkeys || {};
        userBalanceHistory = data.userBalanceHistory || {};
        console.log("✅ Data successfully loaded.");
    } catch (error) {
        console.log("⚠️ Data not found or corrupted, starting with empty data.");
    }
}

// Save data to file
function saveData() {
    fs.writeFileSync(DATA_FILE, JSON.stringify({ userPubkeys, userBalanceHistory }, null, 4));
    console.log("✅ Data successfully saved.");
}

// Format balance
function formatBalance(balance) {
    return (balance / 1e9).toFixed(6);
}

// Fetch validator info
async function getValidatorInfo(pubkey) {
    try {
        const response = await axios.get(API_URL);
        const validators = response.data.result.data.json.data;
        for (let validator of validators) {
            if (validator.validator.pubkey === pubkey) {
                return {
                    pubkey: validator.validator.pubkey,
                    balance: formatBalance(parseInt(validator.balance)),
                    rawBalance: parseInt(validator.balance),
                    status: validator.status,
                    slashed: validator.slashed ?? false,
                    withdrawal_amount: formatBalance(validator.withdrawal_amount ?? 0),
                    index: validator.index ?? "Unknown"
                };
            }
        }
    } catch (error) {
        console.log("⚠️ Error retrieving validator info:", error.message);
        return null;
    }
}

// Update validator data periodically
async function updateValidatorData() {
    console.log("🔄 Updating validator data...");
    for (let userId in userPubkeys) {
        for (let pubkey of userPubkeys[userId]) {
            const info = await getValidatorInfo(pubkey);
            if (info) {
                let previousBalance = userBalanceHistory[userId]?.[pubkey] || null;
                let currentBalance = info.rawBalance;
                let changeStr = "(N/A)";

                if (previousBalance !== null) {
                    let change = currentBalance - previousBalance;
                    changeStr = `${(change / 1e9).toFixed(6)}`;
                }

                userBalanceHistory[userId] = userBalanceHistory[userId] || {};
                userBalanceHistory[userId][pubkey] = currentBalance;
            }
        }
    }
    saveData();
    console.log("✅ Validator data updated.");
}

// /start command
bot.onText(/\/start/, (msg) => {
    bot.sendMessage(msg.chat.id, "🚀 *Welcome to Saandy Dill Validator Checkers!*\n\nUse the following commands:\n"
        + "- `/add_pubkey <pubkey>` - Add pubkey\n"
        + "- `/check` - Check validator status\n"
        + "- `/delete_pubkey <pubkey>` - Remove pubkey", { parse_mode: "Markdown" });
});

// /add_pubkey command
bot.onText(/\/add_pubkey (.+)/, (msg, match) => {
    const chatId = msg.chat.id;
    const pubkey = match[1];
    const userId = chatId.toString();
    userPubkeys[userId] = userPubkeys[userId] || [];
    
    if (userPubkeys[userId].includes(pubkey)) {
        bot.sendMessage(chatId, "✅ *Pubkey has already been added.*", { parse_mode: "Markdown" });
        return;
    }
    
    userPubkeys[userId].push(pubkey);
    saveData();
    bot.sendMessage(chatId, `✅ *Pubkey added:* \`${pubkey}\``, { parse_mode: "Markdown" });
});

// /check command
bot.onText(/\/check/, async (msg) => {
    const chatId = msg.chat.id;
    const userId = chatId.toString();
    
    if (!userPubkeys[userId] || userPubkeys[userId].length === 0) {
        bot.sendMessage(chatId, "⚠️ *You haven't added any pubkeys.*", { parse_mode: "Markdown" });
        return;
    }

    let results = [];
    for (let pubkey of userPubkeys[userId]) {
        const info = await getValidatorInfo(pubkey);
        if (info) {
            let previousBalance = userBalanceHistory[userId]?.[pubkey] || null;
            let currentBalance = info.rawBalance;
            let changeStr = "(N/A)";
            
            if (previousBalance !== null) {
                let change = currentBalance - previousBalance;
                changeStr = `${(change / 1e9).toFixed(6)}`;
            }
            
            userBalanceHistory[userId] = userBalanceHistory[userId] || {};
            userBalanceHistory[userId][pubkey] = currentBalance;
            
            results.push(`*Pubkey:* \`${info.pubkey}\`\n*Balance:* \`${info.balance}\`\n*Last Checked:* \`${formatBalance(previousBalance)}\`\n*Change:* \`${changeStr}\`\n*Point:* \`${(parseFloat(info.balance) * 0.0059).toFixed(4)}\`\n*Status:* \`${info.status}\`\n*Slashed:* \`${info.slashed}\`\n*Withdrawal Amount:* \`${info.withdrawal_amount}\`\n*Index:* \`${info.index}\``);
        } else {
            results.push(`⚠️ *Pubkey not found:* \`${pubkey}\``);
        }
    }
    saveData();
    
    bot.sendMessage(chatId, results.join("\n\n"), { parse_mode: "Markdown" });
});

// Load data on startup
loadData();

// Schedule updates every 5-10 minutes
setInterval(updateValidatorData, Math.floor(Math.random() * (600000 - 300000) + 300000));
