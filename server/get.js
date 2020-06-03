const AWS = require('aws-sdk');

AWS.config.update({ region: 'us-east-2' });
var ddb = new AWS.DynamoDB.DocumentClient();
var collector = null;

function continueScan(data) {
  collector.push(...data.Items);
  if (data.LastEvaluatedKey && Object.keys(data.LastEvaluatedKey).length > 0) { // if this is not empty, then there are more entries in the DB
    console.log('Not done yet, lets keep scanning...');
    return ddb.scan({
      TableName: process.env.DDB_TABLE,
      ExclusiveStartKey: {'service': data.LastEvaluatedKey.service, 'location': data.LastEvaluatedKey.location}
    }).promise().then(continueScan);
  } else {
    return true;
  }
}

function getAllFromDB(start) {
  return ddb.scan({
    TableName: process.env.DDB_TABLE
  }).promise().then(continueScan).then(data => {
    console.log("Scan is all done!");
  });
}

exports.handler = async function(event) {
  collector = [];

  await getAllFromDB();
  let ret = {};

  for (let x = 0; x < collector.length; x++) {
    if (!ret[collector[x].service]) {
      ret[collector[x].service] = [];
    }
    ret[collector[x].service].push(collector[x].location);
  }

  return {
    statusCode: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': '*',
      'Access-Control-Allow-Headers': '*'
    },
    body: JSON.stringify(ret)
  };
};
