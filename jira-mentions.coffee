# Description:
#   Keeps an eye on mentions for JIRA IDs (optionally prefixed) for when they're
#   mentioned in chat, and takes the message with the mention and the author and
#   creates a comment on the JIRA.
#
#   Mostly a shameless rip from stuartf's jira-issues script
#     https://github.com/github/hubot-scripts/blob/master/src/scripts/jira-issues.coffee
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JIRA_URL (format: "https://jira-domain.com:9090")
#   HUBOT_JIRA_IGNORECASE (optional; default is "true")
#   HUBOT_JIRA_USERNAME (optional)
#   HUBOT_JIRA_PASSWORD (optional)
#   HUBOT_JIRA_ISSUES_IGNORE_USERS (optional, format: "user1|user2", default is "jira|github")
#
# Commands:
#
# Author:
#   chrisboulton (heavily inspired by stuartf)

module.exports = (robot) ->
  jiraUrl = process.env.HUBOT_JIRA_URL
  jiraUsername = process.env.HUBOT_JIRA_USERNAME
  jiraPassword = process.env.HUBOT_JIRA_PASSWORD

  auth = "#{jiraUsername}:#{jiraPassword}"
  jiraIgnoreUsers = process.env.HUBOT_JIRA_ISSUES_IGNORE_USERS
  if jiraIgnoreUsers == undefined
    jiraIgnoreUsers = "jira|github"

  messageRegex = /([^\w\-]|^)@(\w+-[0-9]+)(?=[^\w]|$)/gi

  robot.hear messageRegex, (msg) ->
    author = msg.message.user.name
    room   = msg.message.user.room
    return if author.match(new RegExp(jiraIgnoreUsers, 'gi'))

    formattedBody = "{quote}*#{author}:* #{msg.message.text}{quote}"
    data = JSON.stringify({body: formattedBody})

    for i in msg.message.text.match(messageRegex)
      do (i) ->
        issue = i.toUpperCase().replace(/([^\w\-]|^)@/, '')
        console.log(issue)
        robot.http(jiraUrl + "/rest/api/2/issue/#{issue}/comment")
          .header('Content-Type', 'application/json')
          .header('Accept', 'application/json')
          .auth(auth)
          .post(data) (err, res, body) ->
            if err
              robot.logger.error err
              msg.send "#{author}: Sorry, I couldn't capture your thoughts on #{issue}: #{err}"
              return

            if res.headers['content-type'].split(';')[0] != 'application/json'
              robot.logger.error "jira-mention: received #{res.headers['content-type']} back from JIRA instead of JSON"
              msg.send "#{author}: Sorry, I'm not sure if I could capture your thoughts on #{issue}, I didn't get JSON back from JIRA"
              return

            data = null
            try
              data = JSON.parse(body)
            catch err
              robot.logger.error err
              msg.send "#{author}: Sorry, I couldn't capture your thoughts on #{issue}: #{err}"
              return

            if res.statusCode != 201
              messages = data.errorMessages.join(". ")
              robot.logger.error messages
              msg.send "#{author}: Sorry, I couldn't capture your thoughts on #{issue}: #{messages}"
