const AWS = require('aws-sdk');

AWS.config.update({ region: 'us-east-2' });
var ddb = new AWS.DynamoDB.DocumentClient();

function addToDB(service, location) {
  return ddb.put({
    Item: {
      'service': service,
      'location': location,
      'added': Math.floor(new Date().getTime()/1000)
    },
    TableName: process.env.DDB_TABLE
  }).promise().then(data => {
    return data;
  });
}

exports.handler = function(event, context, callback) {
  let ps = [];
  for (let x = 0; x < event.Records.length; x++) {
    let message = event.Records[x].Sns.Message.toLowerCase().replace(/\s+/g, '');
    console.log('Message received from SNS:', message);
    let [action, service, location] = message.split(":");
    
    if (action !== "register") {
      continue;
    }
    
    ps.push(addToDB(service, location).catch(err => {callback(err);}));
  }

  Promise.all(ps).then(() => {
    callback(null, "Success");
  });
};
