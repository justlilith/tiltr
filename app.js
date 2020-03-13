let port = process.env.PORT;
if (port == null || port == "") {
  port = 5000;
}

const express = require('express');
const path = require('path');
const cors = require('cors');

var Twitter = require('twitter');

var client = new Twitter({
  consumer_key: process.env.TWITTER_CONSUMER_KEY,
  consumer_secret: process.env.TWITTER_SECRET_KEY,
  access_token_key: process.env.TWITTER_ACCESS_TOKEN,
  access_token_secret: process.env.TWITTER_ACCESS_TOKEN_SECRET
});

/*

Okay, let's talk about what's going down below.

https://api.twitter.com/1.1/statuses/user_timeline.json

That's the full Twitter API endpoint. The twitter npm pkg takes the initial part
of the URL (up to 1.1) and tacks on the rest of the endpoint. It also adds on
the param flags that Twitter wants. I'm not dealing with the specifics. The
weeds beckon. Instead, I'm pantsing this as much as possible cause isn't that
the goal of abstraction?

Okay, so, replace the client.get first argument with the endpoint taken from
Twitter's dev servers. Pass in params based on the express get wrapper. Colon
notation for things in the URL requested from Firefox or Elm or whatever. It's
late and I don't wanna deal with this more than I have to.

Lilith out.

*/

express()
  .use(cors())
  .use(express.static(path.join(__dirname, 'public')))
  .use(express.static(path.join(__dirname, 'frontend')))
  .get('/', (req, res) => res.sendFile(path.join(__dirname, 'frontend/index.html')))
  .get('/testing', (req, res) => console.log('woo!'))
  .get('/frontend/', (req, res) => res.sendFile(path.join(__dirname, 'frontend/index.html')))

  .get('/tiltrartist/:ausername', cors(), (req, res) =>
    client.get
      ( '/statuses/user_timeline/' //note -- this is the Twitter endpoint, NOT the node url
      , {screen_name : req.params.ausername + '%20-"RT%20%40"', count : 100}
      , function(error, tweets, response)
        { if (!error)
            { res.json(tweets);
            }
            else
            { console.log("oh no; we couldn't get tweets for that user");}
          }
          )
          )
          
          .get('/tiltrterm/:aterm', cors(), (req, res) =>
          client.get
          ( '/search/tweets/' //note -- this is the Twitter endpoint, NOT the node url
          , {q : req.params.aterm + '%20-"RT%20%40"', count : 100}
          , function(error, tweets, response)
          { if (!error)
            { res.json(tweets);
          }
            else
              { console.log("oh no; we couldn't get tweets for that search term");}
          }
        )
      )


  // .get('/search/:search', (req,res) => res.json())
  // .get('/search/:artist')
  .listen(port, () => console.log(`Live! Listening on ${ port }`))
