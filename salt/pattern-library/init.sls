pattern-library-repository:
    builder.git_latest:
        - name: git@github.com:elifesciences/pattern-library.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/pattern-library/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - fetch_pull_requests: True

    file.directory:
        - name: /srv/pattern-library
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - builder: pattern-library-repository

pattern-library-public-directory:
    file.directory:
        - name: /srv/pattern-library
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - pattern-library-repository

npm-install:
    cmd.run:
        - name: npm install
        - cwd: /srv/pattern-library/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - pattern-library-repository

composer-install:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'ci', 'end2end'] %}
        - name: composer1.0 --no-interaction install --no-dev
        {% else %}
        - name: composer1.0 --no-interaction install
        {% endif %}
        - cwd: /srv/pattern-library/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - pattern-library-repository

make:
    pkg.installed

ruby-dev:
    pkg.installed
        
pattern-library-compass:
    gem.installed:
        - name: compass
        - require:
            - pkg: ruby-dev
            - pkg: make

install-gulp:
    npm.installed:
        - name: gulp-cli
        - require:
            - pkg: nodejs
            - pattern-library-compass

run-gulp:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'ci'] %}
        - name: gulp --environment production
        {% else %}
        - name: gulp
        {% endif %}
        - cwd: /srv/pattern-library/
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - install-gulp
            - npm-install

pattern-library-dependencies:
    cmd.run:
        - name: cp -r ./core/styleguide ./public/
        - cwd: /srv/pattern-library
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - run-gulp

pattern-library-nginx-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/pattern-library.conf
        - source: salt://pattern-library/config/etc-nginx-sites-enabled-pattern-library.conf
        - template: jinja
        - require:
            - nginx-config
        - listen_in:
            - service: nginx-server-service
