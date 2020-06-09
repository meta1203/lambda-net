const AWS = require('aws-sdk');

AWS.config.update({ region: process.env.AWS_REGION });
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

function addRoute53(ip, domain) {
  return route53.changeResourceRecordSets({
    ChangeBatch: {
      Changes: [
        {
          Action: "UPSERT", 
          ResourceRecordSet: {
            Name: domain + "." + process.env.ROOT_DOMAIN, 
            ResourceRecords: [
              {
                Value: ip
              }
            ], 
            TTL: 60,
            Type: "A"
          }
        }
      ], 
      Comment: "Entry for IP: " + ip
    }, 
    HostedZoneId: process.env.HOSTED_ZONE_ID
  }).promise().then(wdata => {
    console.log("Successfully updated dns entry");
    console.log(wdata);
    return {'success': true, ip: ip, r53c: wdata, domainName: domain};
  });
}

exports.handler = function(event, context, callback) {
  let ps = [];
  for (let x = 0; x < event.Records.length; x++) {
    let message = event.Records[x].Sns.Message.toLowerCase().replace(/\s+/g, '');
    console.log('Message received from SNS:', message);
    
    let [action, service, ip] = message.split(":");
    let ipPrefix = ip.replace(/\./g, "-");
    
    if (action !== "register") {
      continue;
    }
    
    ps.push(addToDB(service, ipPrefix).catch(err => {callback(err);}));
    ps.push(addRoute53(ip, ipPrefix).catch(err => {callback(err);}));
  }

  Promise.all(ps).then(() => {
    callback(null, "Success");
  });
};
