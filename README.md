# MapKit Token

MapKit JS uses JSON Web Tokens (JWTs) to authenticate map initializations and other API requests. This gem adds an endpoint to a Rails applications to provide MapKit JS with such authentication JWTs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mapkit_token'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mapkit_token

## Usage

Before you can use this gem, you need a Maps Identifer (i.e., Maps ID) and private key that is associated to a Maps ID. If you haven't yet done that, read more about how to do that here:

[Creating a Maps Identifier and a Private Key](https://developer.apple.com/documentation/mapkitjs/creating_a_maps_identifier_and_a_private_key)

You need three things: the private key itself, the MapKit JS Key ID, and your Apple Developer Team ID.

The key can be kept in whichever of these suits the machine the application runs on. Each piece is looked for in an initializer first, then in the Rails credentials, then in the environment; the contents of the key are looked for in all three before a path to it is, so a server carrying the key in its environment answers for credentials that still name a file it does not have.

### The key as a file

Leave the `.p8` Apple gave you in your application folder and name it:

    $ EDITOR=vim rails credentials:edit

```yaml
mapkit:
  auth_key_path: AuthKey_XXXXXXXXXX.p8
  auth_key_id: XXXXXXXXXX
  apple_team_id: XXXXXXXXXX
```

A relative path is read from `Rails.root`; an absolute one is read as it stands. In case you have different AuthKey files for your different environments, edit your environment credentials separately:

    $ EDITOR=vim rails credentials:edit --environment development

The gem provides legacy support for Rails secrets, so if your app uses Rails 4.1 through 5.1, you can store the same information in `/config/secrets.yml` and it will just work.

### The key as contents, in the credentials

Somewhere the `.p8` file itself is awkward to ship -- a container image, a server built from the repository alone -- the contents of the file can be carried instead of a path to it:

```yaml
mapkit:
  auth_key: |
    -----BEGIN PRIVATE KEY-----
    MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
    -----END PRIVATE KEY-----
  auth_key_id: XXXXXXXXXX
  apple_team_id: XXXXXXXXXX
```

### The key in the environment

All three can come from the environment instead, which is what a deployment that keeps its secrets outside the repository wants:

```sh
MAPKIT_AUTH_KEY_ID=XXXXXXXXXX
MAPKIT_APPLE_TEAM_ID=XXXXXXXXXX

# the contents of the .p8 ...
MAPKIT_AUTH_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"

# ... or a path to it, if the file is on the machine
MAPKIT_AUTH_KEY_PATH=/etc/mapkit/AuthKey_XXXXXXXXXX.p8
```

A key is a handful of lines, and not every way of setting an environment variable carries a newline. Both of the shapes that survive being passed around as one line are understood: newlines written out as `\n`, and base64 of the whole file (`base64 -w0 AuthKey_XXXXXXXXXX.p8`).

### The key from an initializer

An application that would rather say all this in code -- reading the key from a secrets manager, say, or from names of its own -- can set it in `config/initializers/mapkit_token.rb`:

```ruby
MapkitToken.setup do |config|
  config.auth_key = Vault.read("mapkit").data[:p8]
  config.auth_key_id = ENV.fetch("A_NAME_OF_OUR_OWN")
  config.apple_team_id = ENV.fetch("ANOTHER_NAME_OF_OUR_OWN")
end
```

`MapkitToken.app_root` can be set the same way, to look for a relative `auth_key_path` somewhere other than `Rails.root`.

### When something is missing

`MapkitToken::ConfigurationError` is raised, saying what was not found and every place it was looked for, rather than failing later with an unreadable key. `MapkitToken.config.auth_key?` answers whether there is a key to be had, for a page that would rather not draw a map it cannot get a token for.

After reloading your application, it will have a new endpoint `/mapkit_token` that returns JWTs that are valid for 30 minutes. The application's hostname is added to the JWT payload to specify that the tokens only can used by the application itself.

Use the endpoint for the `authorizationCallback` function that MapKit JS calls whenever it detects that a new token is needed.

```html
<!DOCTYPE html>
<html>
...
<div id="map" style="width: 800px; height: 600px;"></div>
<script src="https://cdn.apple-mapkit.com/mk/5.0.x/mapkit.js"></script>
<script>
mapkit.init({ authorizationCallback: function(done) { fetch("/mapkit_token")
    .then(res => res.text())
    .then(token => done(token)) /* If successful, return your token to MapKit JS */ 
    .catch(error => { /* Handle error */ });
}});
let map = new mapkit.Map("map", { center: new mapkit.Coordinate(59.329, 18.068) }); 
</script>
...
</html>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/mapkit_token. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the MapkitToken project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/mapkit_token/blob/master/CODE_OF_CONDUCT.md).
