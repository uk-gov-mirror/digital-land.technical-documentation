const govukEleventyPlugin = require('@x-govuk/govuk-eleventy-plugin')

function capitalizeWords(str) {
    return str.replace(/\b\w/g, function(match) {
      return match.toUpperCase();
    });
}

function searchContent(html) {
    return String(html)
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<!--[\s\S]*?-->/g, ' ')
        .replace(/<h[1-6][^>]*>[\s\S]*?<\/h[1-6]>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/\s+/g, ' ')
        .trim();
}

function searchHeadings(html) {
    return Array.from(String(html).matchAll(/<h[1-6][^>]*>([\s\S]*?)<\/h[1-6]>/gi))
        .map(function(match) {
            return searchContent(match[1]);
        })
        .filter(Boolean);
}

function prefixUrl(url, pathPrefix) {
    if (!url || pathPrefix === '/' || URL.canParse(url)) {
        return url;
    }

    return `${pathPrefix.replace(/\/$/, '')}${url}`;
}

module.exports = function(eleventyConfig) {
    const pathPrefix = process.env.GITHUB_ACTIONS ? '/technical-documentation/' : '/'

    // Register the plugin
    eleventyConfig.addPlugin(govukEleventyPlugin,{
        header: {
            logotype: {
                text: 'Digital Land'
            },
            productName: 'Technical Documentation',
            search: {
                indexPath: `${pathPrefix}search-index.json`,
                label: 'Search documentation'
            }
        },
        titleSuffix: 'Digital Land',
        stylesheets:['/assets/wiki.css']
    })
    eleventyConfig.addCollection("allPages", function(collection) {
        return collection.getAll().filter(item => item.outputPath && item.inputPath.endsWith('.md'));
    });
    eleventyConfig.addCollection("sortedByUrl", function(collectionApi) {
        return collectionApi.getAll().sort((a, b) => {
          // Sort by URL
          return a.url.localeCompare(b.url);
        });
    });
    
    // Register specific options
    eleventyConfig.setQuietMode(false)
    eleventyConfig.addFilter('searchContent', searchContent);
    eleventyConfig.addFilter('searchHeadings', searchHeadings);
    eleventyConfig.addFilter('prefixUrl', function(url) {
        return prefixUrl(url, pathPrefix);
    });
    eleventyConfig.addGlobalData("layout", "base.njk");
    eleventyConfig.addPassthroughCopy("assets")
    eleventyConfig.addPassthroughCopy("images");

    // Helper function to create nested structure
    const createNestedStructure = (pages) => {
        const result = {};
    
        pages.forEach(page => {
            // Extract file slug and use it as a key
            const key = page.fileSlug || 'home'; // Default to 'home' if no slug
            const title = page.data.title || capitalizeWords(key.replace(/-/g, ' ')); // Title defaults to slug if none is provided
            const url = page.url || `/`; // Default URL if none is provided
            // Create an object for the page
            const pageObject = {
                title: title,
                url: url,
                children: {} // Initialize empty children
            };
    
            // Break the input path into directories
            const pathParts = page.inputPath.split('/').slice(2);
            // assign base index to home
            if (pathParts[0] === 'index.md') {
                result['home'] = pageObject;
                return;
            }
    
            // Function to recursively insert page into the result structure
            const insertIntoStructure = (structure, parts, pageObj) => {
                const currentDir = parts.shift(); // Get the current directory part
                
                // special handling for index pages, they  are
                // found  at the route
                if (parts.length===1 && parts[0] === 'index.md') {
                    if (!structure[currentDir]) {
                        structure[currentDir] = {
                            title: pageObj.title,
                            url: pageObj.url,
                            children: {}
                        };
                    } else {
                        structure[currentDir].title = pageObj.title;
                        structure[currentDir].url = pageObj.url;
                    }
                    return;
                }
                if (parts.length === 0) {
                    // If no more parts, we're at the page level
                    structure[currentDir] = pageObj;
                    return;
                }
    
                // If directory doesn't exist in the structure, initialize it
                if (!structure[currentDir]) {
                    structure[currentDir] = {
                        title: capitalizeWords(currentDir.replace(/-/g, ' ')),
                        url: '',
                        children: {}
                    };
                }
    
                // Recur deeper into the structure
                insertIntoStructure(structure[currentDir].children, parts, pageObj);
            };
    
            // Insert the page into the nested structure
            insertIntoStructure(result, pathParts, pageObject);
        });
    
        return result;
    };
    
    // Add the custom collection to Eleventy
    eleventyConfig.addCollection("nestedPages", function(collection) {
        const allPages = collection.getAll().sort((a, b) => {
            // Sort by URL
            return a.url.localeCompare(b.url);
          });
        return createNestedStructure(allPages);
    });

  return {
    dataTemplateEngine: 'njk',
    htmlTemplateEngine: 'njk',
    markdownTemplateEngine: 'njk',
    dir: {
      // The folder where all your content will live:
      input: 'docs',
      // Use layouts from the plugin
      includes: "../includes",
      layouts: '../layouts'
    //   layouts: '../node_modules/@x-govuk/govuk-eleventy-plugin/layouts'
    },
    pathPrefix: pathPrefix
  }
};
